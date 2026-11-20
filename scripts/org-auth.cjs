// Internal helper: callers capture this output; never print it in setup logs.
const { execFileSync } = require('node:child_process');
const { realpathSync } = require('node:fs');
const { createRequire } = require('node:module');

(async () => {
  const sfPath = execFileSync('which', ['sf'], { encoding: 'utf8' }).trim();
  const cliRequire = createRequire(realpathSync(sfPath));
  const { Org } = cliRequire('@salesforce/core');
  const org = await Org.create({ aliasOrUsername: process.argv[2] });
  await org.refreshAuth();
  const connection = org.getConnection();
  process.stdout.write(JSON.stringify({ status: 0, result: {
    accessToken: connection.accessToken,
    instanceUrl: connection.instanceUrl,
    id: org.getOrgId(),
    username: org.getUsername(),
    apiVersion: connection.version,
  } }));
})().catch((error) => { console.error(error.message); process.exitCode = 1; });
