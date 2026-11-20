#!/bin/bash -e
sf demoutil org create scratch -f config/project-scratch-def.json -d 30 -w 30 -s -p fsc -e fsc.workshop

# Data Cloud provisioning is available only on workers with the provisioning command.
bash -euo pipefail -c 'commands=$(sf commands --json); if jq -e "any(.[]; .id == \"data:cloud:provision\")" <<< "$commands" >/dev/null; then sf data cloud provision >&2; printf "{\"status\":0}\n"; else printf "{\"status\":0,\"result\":{\"message\":\"Data Cloud provisioning skipped: CLI command unavailable\"}}\n"; fi' --json

sf project deploy start --source-dir force-app --wait 30
sf org assign permsetlicense --name AgentPlatformBuilderPsl --name AgentforceServiceAgentBuilderPsl
sf org assign permset --name FINS_Agentforce_App_Access --name FSCInsurance --name CopilotSalesforceUser --name CopilotSalesforceAdmin --name FSCComprehensive --name Producer_Assist

# The CLI sets up the agent profile and required permissions. Add workshop-specific access.
bash -euo pipefail -c 'agent=$(sf org:create:agent-user --first-name "" --last-name EinsteinServiceAgent --json | jq -er ".result.username"); sf org assign permset --name Producer_Assist --on-behalf-of "$agent" --json' --json

# Each Hosted Scratch line runs in its own shell. Keep command output separate from its JSON result.
bash -euo pipefail -c 'target=$(sf config get target-org --json | jq -er ".result[] | select(.location == \"Local\") | .value"); node scripts/fsc-data-migration/migrate.mjs import --target "$target" --input data/fsc-exports-standard/2026-07-14T-billing-refresh >&2; printf "{\"status\":0}\n"' --json
bash -euo pipefail -c 'target=$(sf config get target-org --json | jq -er ".result[] | select(.location == \"Local\") | .value"); bash scripts/upload-kiran-singh-files.sh "$target" >&2; printf "{\"status\":0}\n"' --json

sf demoutil user password set -p salesforce1 -g User -l User
sf org open -r
