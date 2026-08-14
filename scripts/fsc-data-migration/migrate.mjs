#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import { createReadStream } from 'node:fs';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createInterface } from 'node:readline';
import path from 'node:path';

const CORE_OBJECTS = new Set(['Account', 'Contact', 'Case', 'Opportunity', 'Lead', 'Billing__c']);
const DEFAULT_NAMESPACES = [];
const FSC_STANDARD_PREFIXES = [
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
const EXCLUDED_ENDINGS = [
  'ChangeEvent',
  'Feed',
  'History',
  'Share',
  '__ChangeEvent',
  '__Feed',
  '__History',
  '__Share',
  '__b',
  '__mdt',
];
const SYSTEM_REFERENCE_FIELDS = new Set([
  'CreatedById',
  'LastModifiedById',
  'OwnerId',
  'SystemModstamp',
]);

function usage(message) {
  if (message) console.error(`Error: ${message}\n`);
  console.error(`Usage:
  node migrate.mjs export --source <org> [--output <dir>] [--namespace <prefix>]
  node migrate.mjs import --target <org> --input <export-dir> [--dry-run]

Defaults:
  export namespaces: none. Use --namespace to include legacy managed-package objects.
  export output: data/fsc-exports/<UTC timestamp>`);
  process.exit(message ? 1 : 0);
}

function parseArgs(argv) {
  const [command, ...rest] = argv;
  if (command === '--help' || command === '-h') usage();
  const args = { command, namespaces: [] };
  for (let i = 0; i < rest.length; i += 1) {
    const token = rest[i];
    if (token === '--dry-run') args.dryRun = true;
    else if (token === '--source') args.source = rest[++i];
    else if (token === '--target') args.target = rest[++i];
    else if (token === '--input') args.input = rest[++i];
    else if (token === '--output') args.output = rest[++i];
    else if (token === '--namespace') args.namespaces.push(rest[++i]);
    else if (token === '--help' || token === '-h') usage();
    else usage(`unknown argument ${token}`);
  }
  return args;
}

function sfAuth(org) {
  const stdout = execFileSync(
    'sf',
    ['org', 'display', '--target-org', org, '--json'],
    { encoding: 'utf8', stdio: ['ignore', 'pipe', 'inherit'] },
  );
  const parsed = JSON.parse(stdout);
  if (parsed.status !== 0 || !parsed.result?.accessToken) {
    throw new Error(`Salesforce org authentication failed for ${org}`);
  }
  return {
    accessToken: parsed.result.accessToken,
    apiVersion: parsed.result.apiVersion || '66.0',
    instanceUrl: parsed.result.instanceUrl,
    orgId: parsed.result.id,
    username: parsed.result.username,
  };
}

async function api(auth, resource, options = {}) {
  const url = resource.startsWith('http')
    ? resource
    : `${auth.instanceUrl}${resource.startsWith('/') ? '' : '/'}${resource}`;
  const response = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${auth.accessToken}`,
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });
  const text = await response.text();
  const payload = text ? JSON.parse(text) : null;
  if (!response.ok) {
    const detail = Array.isArray(payload)
      ? payload.map((item) => `${item.errorCode}: ${item.message}`).join('; ')
      : JSON.stringify(payload);
    throw new Error(`${response.status} ${response.statusText}: ${detail}`);
  }
  return payload;
}

function dataPath(auth, suffix) {
  return `/services/data/v${auth.apiVersion}/${suffix}`;
}

async function queryAll(auth, soql) {
  let next = `${dataPath(auth, 'queryAll')}?q=${encodeURIComponent(soql)}`;
  const records = [];
  while (next) {
    const page = await api(auth, next);
    records.push(...page.records);
    next = page.done ? null : page.nextRecordsUrl;
  }
  return records;
}

function selectedObject(name, namespaces) {
  if (CORE_OBJECTS.has(name)) return true;
  if (EXCLUDED_ENDINGS.some((ending) => name.endsWith(ending))) return false;
  if (namespaces.some((prefix) => name.startsWith(prefix))) return true;
  return FSC_STANDARD_PREFIXES.some((prefix) => name.startsWith(prefix));
}

function chunks(values, maximumLength = 17000) {
  const result = [];
  let current = ['Id'];
  let length = 2;
  for (const value of values.filter((item) => item !== 'Id')) {
    if (length + value.length + 2 > maximumLength) {
      result.push(current);
      current = ['Id'];
      length = 2;
    }
    current.push(value);
    length += value.length + 2;
  }
  if (current.length) result.push(current);
  return result;
}

async function exportObject(auth, objectName, describe, outputDir) {
  const queryFields = describe.fields.filter((field) => field.queryable !== false).map((field) => field.name);
  const fieldChunks = chunks(queryFields);
  const byId = new Map();
  for (const fields of fieldChunks) {
    const rows = await queryAll(auth, `SELECT ${fields.join(',')} FROM ${objectName}`);
    for (const row of rows) {
      const id = row.Id;
      const clean = { ...row };
      delete clean.attributes;
      byId.set(id, { ...(byId.get(id) || {}), ...clean });
    }
  }
  const file = `${objectName}.jsonl`;
  const body = [...byId.values()].map((record) => JSON.stringify(record)).join('\n');
  await writeFile(path.join(outputDir, file), body ? `${body}\n` : '', { mode: 0o600 });
  return { file, count: byId.size };
}

async function exportRecordTypes(auth, objectNames) {
  const mapping = {};
  for (let i = 0; i < objectNames.length; i += 100) {
    const names = objectNames.slice(i, i + 100).map((name) => `'${name.replaceAll("'", "\\'")}'`);
    const records = await queryAll(
      auth,
      `SELECT Id,SobjectType,DeveloperName FROM RecordType WHERE SobjectType IN (${names.join(',')})`,
    );
    for (const record of records) {
      mapping[record.Id] = { sobjectType: record.SobjectType, developerName: record.DeveloperName };
    }
  }
  return mapping;
}

async function runExport(args) {
  if (!args.source) usage('export requires --source');
  const auth = sfAuth(args.source);
  const namespaces = args.namespaces.length ? args.namespaces : DEFAULT_NAMESPACES;
  const stamp = new Date().toISOString().replaceAll(':', '').replaceAll('.', '-');
  const outputDir = path.resolve(args.output || `data/fsc-exports/${stamp}`);
  await mkdir(outputDir, { recursive: true, mode: 0o700 });

  const global = await api(auth, dataPath(auth, 'sobjects'));
  const objects = global.sobjects
    .filter((item) => item.queryable && selectedObject(item.name, namespaces))
    .sort((a, b) => a.name.localeCompare(b.name));
  const manifest = {
    formatVersion: 1,
    exportedAt: new Date().toISOString(),
    source: { orgId: auth.orgId, username: auth.username },
    scope: { coreObjects: [...CORE_OBJECTS], namespaces, standardPrefixes: FSC_STANDARD_PREFIXES },
    objects: [],
    recordTypes: {},
    warnings: [],
  };

  console.log(`Discovered ${objects.length} queryable objects in scope.`);
  for (let index = 0; index < objects.length; index += 1) {
    const object = objects[index];
    try {
      const describe = await api(auth, dataPath(auth, `sobjects/${object.name}/describe`));
      const result = await exportObject(auth, object.name, describe, outputDir);
      manifest.objects.push({
        name: object.name,
        label: object.label,
        ...result,
        createable: object.createable,
        fields: describe.fields.map((field) => ({
          name: field.name,
          type: field.type,
          createable: field.createable,
          updateable: field.updateable,
          nillable: field.nillable,
          defaultedOnCreate: field.defaultedOnCreate,
          calculated: field.calculated,
          autoNumber: field.autoNumber,
          referenceTo: field.referenceTo || [],
        })),
      });
      console.log(`[${index + 1}/${objects.length}] ${object.name}: ${result.count}`);
    } catch (error) {
      const warning = `${object.name}: ${error.message}`;
      manifest.warnings.push(warning);
      console.warn(`[${index + 1}/${objects.length}] skipped ${warning}`);
    }
  }
  manifest.recordTypes = await exportRecordTypes(auth, manifest.objects.map((object) => object.name));
  await writeFile(path.join(outputDir, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`, { mode: 0o600 });
  const total = manifest.objects.reduce((sum, object) => sum + object.count, 0);
  console.log(`Export complete: ${manifest.objects.length} objects, ${total} records, ${outputDir}`);
}

async function readJsonLines(file) {
  const records = [];
  const lines = createInterface({ input: createReadStream(file), crlfDelay: Infinity });
  for await (const line of lines) if (line.trim()) records.push(JSON.parse(line));
  return records;
}

function dependencyOrder(objects) {
  const names = new Set(objects.map((object) => object.name));
  const dependencies = new Map();
  for (const object of objects) {
    const required = new Set(
      object.fields
        .filter((field) => field.createable && field.type === 'reference' && !field.nillable && !field.defaultedOnCreate)
        .flatMap((field) => field.referenceTo)
        .filter((name) => names.has(name) && name !== object.name),
    );
    dependencies.set(object.name, required);
  }
  const ordered = [];
  const remaining = new Set(names);
  while (remaining.size) {
    const ready = [...remaining].filter((name) => [...dependencies.get(name)].every((dep) => !remaining.has(dep)));
    if (!ready.length) {
      ordered.push(...[...remaining].sort());
      break;
    }
    ready.sort();
    ordered.push(...ready);
    ready.forEach((name) => remaining.delete(name));
  }
  return ordered;
}

async function targetRecordTypes(auth, objectNames) {
  const mapping = new Map();
  for (let i = 0; i < objectNames.length; i += 100) {
    const names = objectNames.slice(i, i + 100).map((name) => `'${name.replaceAll("'", "\\'")}'`);
    const records = await queryAll(
      auth,
      `SELECT Id,SobjectType,DeveloperName FROM RecordType WHERE SobjectType IN (${names.join(',')})`,
    );
    records.forEach((record) => mapping.set(`${record.SobjectType}:${record.DeveloperName}`, record.Id));
  }
  return mapping;
}

async function composite(auth, method, objectName, records) {
  const results = [];
  for (let i = 0; i < records.length; i += 200) {
    const batch = records.slice(i, i + 200);
    const response = await api(auth, dataPath(auth, 'composite/sobjects'), {
      method,
      body: JSON.stringify({
        allOrNone: false,
        records: batch.map((record) => ({ attributes: { type: objectName }, ...record })),
      }),
    });
    results.push(...response);
  }
  return results;
}

function createPayload(record, object, idMap, sourceRecordTypes, targetRecordTypeMap) {
  const payload = {};
  const deferred = {};
  const blocking = [];
  for (const field of object.fields) {
    if (!field.createable || field.name === 'Id' || SYSTEM_REFERENCE_FIELDS.has(field.name)) continue;
    const value = record[field.name];
    if (value === undefined || value === null) continue;
    if (field.name === 'RecordTypeId') {
      const sourceType = sourceRecordTypes[value];
      const mapped = sourceType
        ? targetRecordTypeMap.get(`${object.name}:${sourceType.developerName}`)
        : null;
      if (mapped) payload.RecordTypeId = mapped;
      continue;
    }
    if (field.type !== 'reference') {
      payload[field.name] = value;
      continue;
    }
    const mapped = idMap.get(value);
    if (mapped) payload[field.name] = mapped;
    else if (field.nillable || field.defaultedOnCreate) deferred[field.name] = value;
      else blocking.push(`${field.name}=${value}`);
  }
  if (object.name === 'Account' && record.IsPersonAccount === true) delete payload.Name;
  return { payload, deferred, blocking };
}

async function runImport(args) {
  if (!args.target || !args.input) usage('import requires --target and --input');
  const inputDir = path.resolve(args.input);
  const manifest = JSON.parse(await readFile(path.join(inputDir, 'manifest.json'), 'utf8'));
  if (manifest.formatVersion !== 1) throw new Error(`Unsupported export format ${manifest.formatVersion}`);
  const auth = sfAuth(args.target);
  if (auth.orgId === manifest.source.orgId) throw new Error('Refusing to import back into the source org');

  const global = await api(auth, dataPath(auth, 'sobjects'));
  const targetObjects = new Map(global.sobjects.map((object) => [object.name, object]));
  const eligible = [];
  const skipped = [];
  const schemaWarnings = [];
  for (const object of manifest.objects) {
    const target = targetObjects.get(object.name);
    if (!target?.createable) {
      skipped.push(object);
      continue;
    }
    const targetDescribe = await api(auth, dataPath(auth, `sobjects/${object.name}/describe`));
    const targetFields = new Map(targetDescribe.fields.map((field) => [field.name, field]));
    const compatibleFields = object.fields
      .filter((field) => field.name === 'Id' || (field.createable && targetFields.get(field.name)?.createable))
      .map((field) => {
        const targetField = targetFields.get(field.name);
        return targetField
          ? {
              ...field,
              type: targetField.type,
              createable: targetField.createable,
              updateable: targetField.updateable,
              nillable: targetField.nillable,
              defaultedOnCreate: targetField.defaultedOnCreate,
              referenceTo: targetField.referenceTo || [],
            }
          : field;
      });
    const dropped = object.fields.filter(
      (field) => field.createable && !targetFields.get(field.name)?.createable,
    );
    if (dropped.length) {
      schemaWarnings.push({ object: object.name, droppedFields: dropped.map((field) => field.name) });
    }
    eligible.push({ ...object, fields: compatibleFields });
  }
  const order = dependencyOrder(eligible);
  const recordTypeMap = await targetRecordTypes(auth, eligible.map((object) => object.name));
  const idMap = new Map();
  const deferred = [];
  const report = {
    importedAt: new Date().toISOString(),
    sourceOrgId: manifest.source.orgId,
    targetOrgId: auth.orgId,
    dryRun: Boolean(args.dryRun),
    objects: [],
    skippedObjects: skipped.map((object) => object.name),
    schemaWarnings,
    automaticSkips: [],
    failures: [],
  };

  for (const name of order) {
    const object = eligible.find((item) => item.name === name);
    const records = await readJsonLines(path.join(inputDir, object.file));
    const pending = [];
    for (const record of records) {
      if (idMap.has(record.Id)) {
        report.automaticSkips.push({ object: name, sourceId: record.Id, reason: 'already created by parent record' });
        continue;
      }
      if (name === 'AccountContactRelation' && record.IsDirect === true) {
        report.automaticSkips.push({ object: name, sourceId: record.Id, reason: 'direct relation is system generated' });
        continue;
      }
      const built = createPayload(record, object, idMap, manifest.recordTypes, recordTypeMap);
      if (built.blocking.length) {
        report.failures.push({ object: name, sourceId: record.Id, errors: built.blocking });
        continue;
      }
      pending.push({
        sourceId: record.Id,
        personContactSourceId: name === 'Account' ? record.PersonContactId : null,
        payload: built.payload,
        deferred: built.deferred,
      });
    }
    if (args.dryRun) {
      pending.forEach((item) => {
        idMap.set(item.sourceId, `DRYRUN:${item.sourceId}`);
        if (item.personContactSourceId) {
          idMap.set(item.personContactSourceId, `DRYRUN:${item.personContactSourceId}`);
        }
      });
      report.objects.push({ name, source: records.length, ready: pending.length, created: 0 });
      console.log(`[dry-run] ${name}: ${pending.length}/${records.length} ready`);
      continue;
    }
    const results = await composite(auth, 'POST', name, pending.map((item) => item.payload));
    let created = 0;
    results.forEach((result, index) => {
      const item = pending[index];
      if (result.success) {
        created += 1;
        idMap.set(item.sourceId, result.id);
        deferred.push({ object: name, targetId: result.id, fields: item.deferred });
      } else {
        report.failures.push({ object: name, sourceId: item.sourceId, errors: result.errors });
      }
    });
    if (name === 'Account') {
      const personAccountTargets = new Map();
      results.forEach((result, index) => {
        const sourceContactId = pending[index].personContactSourceId;
        if (result.success && sourceContactId) personAccountTargets.set(result.id, sourceContactId);
      });
      const targetIds = [...personAccountTargets.keys()];
      for (let i = 0; i < targetIds.length; i += 100) {
        const ids = targetIds.slice(i, i + 100).map((id) => `'${id}'`);
        const accounts = await queryAll(auth, `SELECT Id,PersonContactId FROM Account WHERE Id IN (${ids.join(',')})`);
        accounts.forEach((account) => {
          if (account.PersonContactId) idMap.set(personAccountTargets.get(account.Id), account.PersonContactId);
        });
      }
    }
    report.objects.push({ name, source: records.length, ready: pending.length, created });
    console.log(`${name}: ${created}/${records.length} created`);
  }

  if (!args.dryRun) {
    const byObject = new Map();
    for (const item of deferred) {
      const payload = { Id: item.targetId };
      for (const [field, sourceId] of Object.entries(item.fields)) {
        const mapped = idMap.get(sourceId);
        if (mapped) payload[field] = mapped;
      }
      if (Object.keys(payload).length > 1) {
        if (!byObject.has(item.object)) byObject.set(item.object, []);
        byObject.get(item.object).push(payload);
      }
    }
    for (const [objectName, updates] of byObject) {
      const results = await composite(auth, 'PATCH', objectName, updates);
      results.forEach((result, index) => {
        if (!result.success) report.failures.push({ object: objectName, targetId: updates[index].Id, errors: result.errors });
      });
    }
  }

  const reportFile = path.join(inputDir, `import-report-${auth.orgId}.json`);
  await writeFile(reportFile, `${JSON.stringify(report, null, 2)}\n`, { mode: 0o600 });
  console.log(`Import ${args.dryRun ? 'validation' : 'execution'} complete. Report: ${reportFile}`);
  if (report.failures.length) process.exitCode = 2;
}

const args = parseArgs(process.argv.slice(2));
try {
  if (args.command === 'export') await runExport(args);
  else if (args.command === 'import') await runImport(args);
  else usage('command must be export or import');
} catch (error) {
  console.error(error.stack || error.message);
  process.exit(1);
}
