#!/usr/bin/env node

import { createReadStream } from 'node:fs';
import { copyFile, mkdir, readFile, writeFile } from 'node:fs/promises';
import { createInterface } from 'node:readline';
import path from 'node:path';

const CORE_OBJECTS = new Set(['Account', 'Contact', 'Case', 'Opportunity', 'Lead', 'Billing__c']);
const MANAGED_PREFIXES = ['FinServ__', 'vlocity_ins__', 'vlocity_ins_fsc__', 'et4ae5__'];
const STANDARD_FSC_PREFIXES = [
  'AccountAccountRelation',
  'AccountContactRelation',
  'AssetRelationship',
  'BusinessMilestone',
  'Claim',
  'Financial',
  'Insurance',
  'InsPolicy',
  'Interaction',
  'LoanApplicant',
  'LoanApplication',
  'PartyCertifiedCapacity',
  'PartyConsent',
  'PartyExpense',
  'PartyIncome',
  'Referral',
  'ResidentialLoanApplication',
];

function usage(message) {
  if (message) console.error(`Error: ${message}\n`);
  console.error(`Usage:
  node scripts/fsc-data-migration/standardize-export.mjs --input <export-dir> [--output <dir>]

Creates a copy of an FSC export that keeps core CRM and standard FSC objects, drops
legacy managed-package objects, and strips managed-package fields from remaining records.`);
  process.exit(message ? 1 : 0);
}

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === '--input') args.input = argv[++i];
    else if (token === '--output') args.output = argv[++i];
    else if (token === '--help' || token === '-h') usage();
    else usage(`unknown argument ${token}`);
  }
  if (!args.input) usage('missing --input');
  return args;
}

function isManagedName(name) {
  return MANAGED_PREFIXES.some((prefix) => name.startsWith(prefix));
}

function isStandardObject(name) {
  if (CORE_OBJECTS.has(name)) return true;
  if (isManagedName(name)) return false;
  return STANDARD_FSC_PREFIXES.some((prefix) => name.startsWith(prefix));
}

async function readJsonLines(file) {
  const records = [];
  const lines = createInterface({ input: createReadStream(file), crlfDelay: Infinity });
  for await (const line of lines) {
    if (line.trim()) records.push(JSON.parse(line));
  }
  return records;
}

function cleanRecord(record) {
  return Object.fromEntries(
    Object.entries(record).filter(([field]) => !isManagedName(field)),
  );
}

const args = parseArgs(process.argv.slice(2));
const inputDir = path.resolve(args.input);
const outputDir = path.resolve(args.output || `data/fsc-exports-standard/${path.basename(inputDir)}`);
const manifest = JSON.parse(await readFile(path.join(inputDir, 'manifest.json'), 'utf8'));

await mkdir(outputDir, { recursive: true, mode: 0o700 });

const keptObjects = [];
const droppedObjects = [];
for (const object of manifest.objects) {
  if (!isStandardObject(object.name)) {
    droppedObjects.push(object.name);
    continue;
  }

  const records = await readJsonLines(path.join(inputDir, object.file));
  const cleanedRecords = records.map(cleanRecord);
  await writeFile(
    path.join(outputDir, object.file),
    cleanedRecords.length ? `${cleanedRecords.map((record) => JSON.stringify(record)).join('\n')}\n` : '',
    { mode: 0o600 },
  );

  const fields = object.fields.filter((field) => !isManagedName(field.name));
  keptObjects.push({
    ...object,
    fields,
    count: cleanedRecords.length,
  });
}

const keptNames = new Set(keptObjects.map((object) => object.name));
const recordTypes = Object.fromEntries(
  Object.entries(manifest.recordTypes || {}).filter(([, value]) => keptNames.has(value.sobjectType)),
);

const standardizedManifest = {
  ...manifest,
  standardizedAt: new Date().toISOString(),
  standardization: {
    managedPrefixesDropped: MANAGED_PREFIXES,
    droppedObjects,
    note: 'Core CRM and standard FSC/insurance objects retained; legacy managed-package objects and fields removed.',
  },
  scope: {
    coreObjects: [...CORE_OBJECTS],
    namespaces: [],
    standardPrefixes: STANDARD_FSC_PREFIXES,
  },
  objects: keptObjects,
  recordTypes,
};

await writeFile(
  path.join(outputDir, 'manifest.json'),
  `${JSON.stringify(standardizedManifest, null, 2)}\n`,
  { mode: 0o600 },
);

for (const file of ['import-report.json']) {
  try {
    await copyFile(path.join(inputDir, file), path.join(outputDir, file));
  } catch {
    // Optional report file may not exist.
  }
}

const recordCount = keptObjects.reduce((sum, object) => sum + object.count, 0);
console.log(`Standard export written: ${outputDir}`);
console.log(`Kept ${keptObjects.length} objects / ${recordCount} records.`);
console.log(`Dropped ${droppedObjects.length} managed-package objects.`);
