# Financial Services Cloud data migration

This utility exports Account, Contact, Case, Opportunity, Lead, Billing__c, and standard Financial Services Cloud / Insurance objects from one authenticated Salesforce org. It imports the records into another FSC org while remapping Salesforce IDs.

## Scope

The default discovery scope includes:

- `Account`, `Contact`, `Case`, `Opportunity`, `Lead`, and `Billing__c`
- standard FSC and insurance objects discovered by the prefixes recorded in `migrate.mjs`
- optional legacy managed-package objects only when `--namespace` is provided

History, feed, share, change-event, big-object, and custom-metadata entities are excluded because they are not portable business records. The manifest records every discovered object, field, record count, warning, package namespace, and source record type mapping.

## Export

Authenticate the source org with Salesforce CLI, then run:

```bash
node scripts/fsc-data-migration/migrate.mjs export --source fins@agent.force
```

Exports are written under `data/fsc-exports/`, with directory and file permissions limited to the local user. This directory is git-ignored because it can contain PII and financial data.

By default, legacy managed-package namespaces are not exported. To include them for a legacy target org, repeat `--namespace`:

```bash
node scripts/fsc-data-migration/migrate.mjs export \
  --source fins@agent.force \
  --namespace FinServ__
```

To convert an older export to the standard FSC shape, run:

```bash
node scripts/fsc-data-migration/standardize-export.mjs \
  --input data/fsc-exports/<timestamp>
```

The standardized copy is written under `data/fsc-exports-standard/`. It keeps core CRM and standard FSC/Insurance objects, removes `FinServ__`, `vlocity_ins__`, `vlocity_ins_fsc__`, and `et4ae5__` objects, and strips those managed-package fields from retained records.

## Import

The target org must be a different, authenticated FSC org with compatible objects, fields, record types, features, and managed-package versions. First run a no-write validation:

```bash
node scripts/fsc-data-migration/migrate.mjs import \
  --target target-fsc-alias \
  --input data/fsc-exports/<timestamp> \
  --dry-run
```

Then run the import:

```bash
node scripts/fsc-data-migration/migrate.mjs import \
  --target target-fsc-alias \
  --input data/fsc-exports/<timestamp>
```

The importer:

1. refuses to import into the source org;
2. skips objects absent or non-createable in the target;
3. maps record types by object and DeveloperName;
4. reconciles source fields with the target object's createable schema;
5. orders objects by required lookup/master-detail dependencies;
6. creates Person Accounts without the read-only `Name` field and maps their generated Person Contacts;
7. skips Person Contacts and direct Account Contact Relationships that Salesforce generates automatically;
8. remaps parent IDs during create;
9. resolves optional and circular lookups in a second update pass; and
10. writes an `import-report-<target-org-id>.json` file with counts and record-level failures.

## Important limitations

- Metadata, users, queues, products, price books, files, activities, and setup/configuration records outside the stated scope are not migrated.
- Target validation rules, duplicate rules, flows, triggers, restricted picklists, encryption, and required fields can reject records. Review the generated import report.
- Owner IDs and audit fields are intentionally not copied. Target defaults apply.
- Run the import into a sandbox first. A blank org is strongly preferred because this utility inserts records; it does not deduplicate or update existing business data.
- Keep the export encrypted at rest and delete it when the migration is complete.
