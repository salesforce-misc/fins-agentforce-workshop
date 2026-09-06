#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: ./orgInit.sh [options]

Creates a scratch org, deploys the FINS Agentforce metadata, provisions the
primary admin and Service Agent user, imports the standard FSC data export,
and uploads the Kiran Singh files.

Options:
  --alias <alias>          Scratch org alias. Default: fins-af-init-<UTC timestamp>
  --username <username>    Scratch org admin username. Default: auto-generated
  --admin-email <email>    Scratch org admin email. Default: supplied --username
  --existing-org <alias>   Resume initialization of an existing scratch org.
  --devhub <alias>         Dev Hub alias or username. Default: devhub
  --duration <days>        Scratch org duration. Default: 30
  --definition <path>      Scratch org definition. Default: config/project-scratch-def.json
  --data <path>            Standardized data export directory.
                           Default: data/fsc-exports-standard/2026-07-14T-billing-refresh
  --account-name <name>    Account name for file upload. Default: Kiran Singh
  --skip-data-cloud-provisioning
                           Skip Data Cloud provisioning after scratch org creation.
  --skip-metadata         Skip metadata deployment when resuming an initialized org.
  --skip-permissions       Skip standard permission set assignment.
  --skip-agent-user        Skip dedicated Service Agent user creation.
  --skip-data              Deploy metadata and upload files, but skip data import.
  --skip-files             Create org/deploy/import data, but skip file upload.
  -h, --help               Show this help.

Examples:
  ./orgInit.sh
  ./orgInit.sh --alias rt-test-afdc --username rt@test.afdc
  ./orgInit.sh --alias fins-af-demo --duration 7
  ./orgInit.sh --devhub my-devhub --account-name "Kiran Singh"
USAGE
}

timestamp="$(date -u +%Y%m%d%H%M%S)"
scratch_alias="fins-af-init-${timestamp}"
scratch_username_override=""
scratch_admin_email_override=""
existing_org=""
devhub="devhub"
duration_days="30"
definition_file="config/project-scratch-def.json"
metadata_source_dir="force-app"
data_dir="data/fsc-exports-standard/2026-07-14T-billing-refresh"
account_name="Kiran Singh"
skip_data_cloud_provisioning="false"
skip_metadata="false"
skip_permissions="false"
skip_agent_user="false"
skip_data="false"
skip_files="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --alias)
      scratch_alias="${2:?--alias requires a value}"
      shift 2
      ;;
    --username)
      scratch_username_override="${2:?--username requires a value}"
      shift 2
      ;;
    --admin-email)
      scratch_admin_email_override="${2:?--admin-email requires a value}"
      shift 2
      ;;
    --existing-org)
      existing_org="${2:?--existing-org requires a value}"
      shift 2
      ;;
    --devhub)
      devhub="${2:?--devhub requires a value}"
      shift 2
      ;;
    --duration)
      duration_days="${2:?--duration requires a value}"
      shift 2
      ;;
    --definition)
      definition_file="${2:?--definition requires a value}"
      shift 2
      ;;
    --data)
      data_dir="${2:?--data requires a value}"
      shift 2
      ;;
    --account-name)
      account_name="${2:?--account-name requires a value}"
      shift 2
      ;;
    --skip-data-cloud-provisioning)
      skip_data_cloud_provisioning="true"
      shift
      ;;
    --skip-metadata)
      skip_metadata="true"
      shift
      ;;
    --skip-permissions)
      skip_permissions="true"
      shift
      ;;
    --skip-agent-user)
      skip_agent_user="true"
      shift
      ;;
    --skip-data)
      skip_data="true"
      shift
      ;;
    --skip-files)
      skip_files="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="${script_dir}"
cd "${project_dir}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "Required file not found: $1" >&2
    exit 1
  fi
}

require_dir() {
  if [[ ! -d "$1" ]]; then
    echo "Required directory not found: $1" >&2
    exit 1
  fi
}

require_command sf
require_command jq
require_command node
require_command curl
require_command base64

permission_sets=(
  "FINS_Agentforce_App_Access|FINS Agentforce App Access"
  "FSCInsurance|FSC Insurance"
  "InsurancePolicyAndClaim|Insurance Policy and Claims"
  "FSCFoundations|Financial Services Cloud Foundations"
  "ServiceLightningKnowledgeManager|Lightning Knowledge Manager"
  "InsuranceClaimMgmt|Insurance Claims Management"
  "InsurancePolicyAdminQuoting|Insurance Policy Administration Quoting"
  "CopilotSalesforceUser|Access Agentforce Default Agent"
  "CopilotSalesforceAdmin|Agentforce Default Admin"
  "ServiceUserPsl|Service Cloud User"
  "FSCComprehensive|Financial Services Cloud Comprehensive"
  "Producer_Assist|Producer Assist"
)

permission_set_licenses=(
  "AgentPlatformBuilderPsl|Agent platform builder"
  "AgentforceServiceAgentBuilderPsl|Agentforce Service Agent Builder"
)

agent_permission_sets=(
  "AgentforceServiceAgentBase|Agentforce Service Agent Object Access"
  "AgentforceServiceAgentUser|Agentforce Service Agent User"
  "EinsteinGPTPromptTemplateUser|Prompt Template User"
  "Producer_Assist|Producer Assist"
)

agent_username=""

soql_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\'/\\\'}"
  printf '%s' "${value}"
}

sf_query() {
  local org="$1"
  local query="$2"
  sf data query --query "${query}" --target-org "${org}" --json
}

sf_rest() {
  local org="$1"
  local method="$2"
  local resource="$3"
  local body="${4:-}"
  local org_json access_token instance_url

  org_json="$(sf org display --target-org "${org}" --verbose --json)"
  access_token="$(jq -r '.result.accessToken // empty' <<< "${org_json}")"
  instance_url="$(jq -r '.result.instanceUrl // empty' <<< "${org_json}")"

  if [[ -z "${access_token}" || -z "${instance_url}" ]]; then
    echo "Could not read auth details for org: ${org}" >&2
    return 1
  fi

  if [[ -n "${body}" ]]; then
    curl --fail --silent --show-error \
      --request "${method}" \
      --header "Authorization: Bearer ${access_token}" \
      --header "Content-Type: application/json" \
      --data "${body}" \
      "${instance_url}${resource}"
  else
    curl --fail --silent --show-error \
      --request "${method}" \
      --header "Authorization: Bearer ${access_token}" \
      --header "Content-Type: application/json" \
      "${instance_url}${resource}"
  fi
}

sf_has_command() {
  local command_id="$1"
  sf commands --json 2>/dev/null | jq -e --arg command_id "${command_id}" 'any(.[]; .id == $command_id)' >/dev/null
}

provision_data_cloud() {
  local org="$1"

  echo "Provisioning Data Cloud for ${org}."

  if sf_has_command "data:cloud:provision"; then
    sf data cloud provision --target-org "${org}"
    echo "Data Cloud provisioning command completed."
  else
    echo "Data Cloud provisioning command not found in this Salesforce CLI installation." >&2
    echo "Expected command: sf data cloud provision --target-org ${org}" >&2
    echo "Install or link the Data Cloud CLI plugin, then rerun this script or run the command above manually." >&2
  fi
}

assign_permission_sets() {
  local org="$1"
  local username="$2"
  local user_query user_id missing=0 assigned=0 skipped=0 failed=0

  user_query="$(sf_query "${org}" "SELECT Id, Username FROM User WHERE Username = '$(soql_escape "${username}")' LIMIT 1")"
  user_id="$(jq -r '.result.records[0].Id // empty' <<< "${user_query}")"

  if [[ -z "${user_id}" ]]; then
    echo "Could not find main user '${username}' for permission assignment." >&2
    return 1
  fi

  echo "Assigning permission sets to ${username} (${user_id})."

  for entry in "${permission_sets[@]}"; do
    local api_name label permission_query permission_set_id existing_query existing_count payload create_status
    api_name="${entry%%|*}"
    label="${entry#*|}"

    permission_query="$(sf_query "${org}" "SELECT Id, Name, Label FROM PermissionSet WHERE Name = '${api_name}' LIMIT 1")"
    permission_set_id="$(jq -r '.result.records[0].Id // empty' <<< "${permission_query}")"

    if [[ -z "${permission_set_id}" ]]; then
      echo "Missing permission set in this org: ${label} (${api_name})"
      missing=$((missing + 1))
      continue
    fi

    existing_query="$(
      sf_query "${org}" \
        "SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = '${user_id}' AND PermissionSetId = '${permission_set_id}' LIMIT 1"
    )"
    existing_count="$(jq -r '.result.totalSize' <<< "${existing_query}")"

    if [[ "${existing_count}" != "0" ]]; then
      echo "Already assigned: ${label} (${api_name})"
      skipped=$((skipped + 1))
      continue
    fi

    payload="$(jq -n --arg assignee_id "${user_id}" --arg permission_set_id "${permission_set_id}" \
      '{AssigneeId: $assignee_id, PermissionSetId: $permission_set_id}')"

    set +e
    sf_rest "${org}" "POST" "/services/data/v66.0/sobjects/PermissionSetAssignment" "${payload}" >/dev/null
    create_status=$?
    set -e

    if [[ ${create_status} -eq 0 ]]; then
      echo "Assigned: ${label} (${api_name})"
      assigned=$((assigned + 1))
    else
      echo "Failed to assign: ${label} (${api_name})" >&2
      failed=$((failed + 1))
    fi
  done

  echo "Permission assignment summary: ${assigned} assigned, ${skipped} already assigned, ${missing} missing, ${failed} failed."
  [[ ${failed} -eq 0 ]]
}

assign_permission_set_licenses() {
  local org="$1"
  local username="$2"
  local user_query user_id missing=0 assigned=0 skipped=0 failed=0

  user_query="$(sf_query "${org}" "SELECT Id, Username FROM User WHERE Username = '$(soql_escape "${username}")' LIMIT 1")"
  user_id="$(jq -r '.result.records[0].Id // empty' <<< "${user_query}")"

  if [[ -z "${user_id}" ]]; then
    echo "Could not find main user '${username}' for permission set license assignment." >&2
    return 1
  fi

  echo "Assigning permission set licenses to ${username} (${user_id})."

  for entry in "${permission_set_licenses[@]}"; do
    local api_name label license_query license_id existing_query existing_count assignment_json assignment_status duplicate_count
    api_name="${entry%%|*}"
    label="${entry#*|}"

    license_query="$(
      sf_query "${org}" \
        "SELECT Id, DeveloperName, MasterLabel FROM PermissionSetLicense WHERE DeveloperName = '${api_name}' LIMIT 1"
    )"
    license_id="$(jq -r '.result.records[0].Id // empty' <<< "${license_query}")"

    if [[ -z "${license_id}" ]]; then
      echo "Missing permission set license in this org: ${label} (${api_name})"
      missing=$((missing + 1))
      continue
    fi

    existing_query="$(
      sf_query "${org}" \
        "SELECT Id FROM PermissionSetLicenseAssign WHERE AssigneeId = '${user_id}' AND PermissionSetLicenseId = '${license_id}' LIMIT 1"
    )"
    existing_count="$(jq -r '.result.totalSize' <<< "${existing_query}")"

    if [[ "${existing_count}" != "0" ]]; then
      echo "Already assigned PSL: ${label} (${api_name})"
      skipped=$((skipped + 1))
      continue
    fi

    set +e
    assignment_json="$(
      sf org assign permsetlicense \
        --name "${api_name}" \
        --on-behalf-of "${username}" \
        --target-org "${org}" \
        --json
    )"
    assignment_status=$?
    set -e

    if [[ ${assignment_status} -eq 0 ]]; then
      echo "Assigned PSL: ${label} (${api_name})"
      assigned=$((assigned + 1))
      continue
    fi

    duplicate_count="$(
      jq '[.result.failures[]? | select(.message | contains("Duplicate"))] | length' \
        <<< "${assignment_json}"
    )"
    if [[ "${duplicate_count}" != "0" ]]; then
      echo "Already assigned PSL: ${label} (${api_name})"
      skipped=$((skipped + 1))
      continue
    fi

    echo "Failed to assign PSL: ${label} (${api_name})" >&2
    jq . <<< "${assignment_json}" >&2 || echo "${assignment_json}" >&2
    failed=$((failed + 1))
  done

  echo "PSL assignment summary: ${assigned} assigned, ${skipped} already assigned, ${missing} missing, ${failed} failed."
  [[ ${failed} -eq 0 ]]
}

ensure_agent_user() {
  local org="$1"
  local existing_query create_json create_status user_verification_query user_verification_count

  existing_query="$(
    sf_query "${org}" \
      "SELECT Id, Username FROM User WHERE IsActive = true AND Profile.Name = 'Einstein Agent User' ORDER BY CreatedDate LIMIT 1"
  )"
  agent_username="$(jq -r '.result.records[0].Username // empty' <<< "${existing_query}")"

  if [[ -n "${agent_username}" ]]; then
    echo "Using existing Service Agent user: ${agent_username}."
  else
    if ! sf_has_command "org:create:agent-user"; then
      echo "Required command not found: sf org create agent-user" >&2
      return 1
    fi

    echo "Creating dedicated Service Agent user."
    set +e
    create_json="$(
      sf org create agent-user \
        --first-name "" \
        --last-name "EinsteinServiceAgent" \
        --target-org "${org}" \
        --json
    )"
    create_status=$?
    set -e

    if [[ ${create_status} -ne 0 ]]; then
      echo "Service Agent user creation failed." >&2
      jq . <<< "${create_json}" >&2 || echo "${create_json}" >&2
      return "${create_status}"
    fi

    agent_username="$(jq -r '.result.username // empty' <<< "${create_json}")"
    if [[ -z "${agent_username}" ]]; then
      echo "Service Agent user creation did not return a username." >&2
      return 1
    fi

    echo "Service Agent user created: ${agent_username}."
  fi

  user_verification_query="$(
    sf_query "${org}" \
      "SELECT Id FROM User WHERE Username = '$(soql_escape "${agent_username}")' AND IsActive = true AND Profile.Name = 'Einstein Agent User' LIMIT 1"
  )"
  user_verification_count="$(jq -r '.result.totalSize' <<< "${user_verification_query}")"

  if [[ "${user_verification_count}" != "1" ]]; then
    echo "Service Agent user ${agent_username} is missing, inactive, or not on the Einstein Agent User profile." >&2
    return 1
  fi

  for entry in "${agent_permission_sets[@]}"; do
    local api_name label assignment_json assignment_status duplicate_count
    api_name="${entry%%|*}"
    label="${entry#*|}"

    set +e
    assignment_json="$(
      sf org assign permset \
        --name "${api_name}" \
        --on-behalf-of "${agent_username}" \
        --target-org "${org}" \
        --json
    )"
    assignment_status=$?
    set -e

    if [[ ${assignment_status} -eq 0 ]]; then
      echo "Assigned agent permission set: ${label} (${api_name})"
      continue
    fi

    duplicate_count="$(
      jq '[.result.failures[]? | select(.message | contains("Duplicate PermissionSetAssignment"))] | length' \
        <<< "${assignment_json}"
    )"
    if [[ "${duplicate_count}" != "0" ]]; then
      echo "Already assigned agent permission set: ${label} (${api_name})"
      continue
    fi

    echo "Failed to ensure agent permission set: ${label} (${api_name})" >&2
    jq . <<< "${assignment_json}" >&2 || echo "${assignment_json}" >&2
    return 1
  done

  echo "Verified Service Agent user and ${#agent_permission_sets[@]}/${#agent_permission_sets[@]} required permission sets."
}

require_file "sfdx-project.json"
require_file "${definition_file}"
require_dir "${metadata_source_dir}"
require_file "scripts/fsc-data-migration/migrate.mjs"

if [[ "${skip_data}" != "true" ]]; then
  require_dir "${data_dir}"
  require_file "${data_dir}/manifest.json"
fi

if [[ "${skip_files}" != "true" ]]; then
  require_file "scripts/upload-kiran-singh-files.sh"
  require_dir "data/kiran-singh-files"
fi

if [[ -n "${existing_org}" ]]; then
  scratch_alias="${existing_org}"
  echo "Resuming initialization of scratch org '${scratch_alias}'."
  org_json="$(sf org display --target-org "${scratch_alias}" --json)"
  scratch_username="$(jq -r '.result.username // empty' <<< "${org_json}")"
  scratch_org_id="$(jq -r '.result.id // empty' <<< "${org_json}")"
else
  echo "Creating scratch org '${scratch_alias}' using Dev Hub '${devhub}'."
  create_args=(
    sf org create scratch
    --definition-file "${definition_file}"
    --alias "${scratch_alias}"
    --duration-days "${duration_days}"
    --target-dev-hub "${devhub}"
    --wait 30
    --json
  )
  if [[ -n "${scratch_username_override}" ]]; then
    create_args+=(--username "${scratch_username_override}")
  fi
  if [[ -z "${scratch_admin_email_override}" && -n "${scratch_username_override}" ]]; then
    scratch_admin_email_override="${scratch_username_override}"
  fi
  if [[ -n "${scratch_admin_email_override}" ]]; then
    create_args+=(--admin-email "${scratch_admin_email_override}")
  fi

  set +e
  create_json="$("${create_args[@]}")"
  create_status=$?
  set -e

  if [[ ${create_status} -ne 0 ]]; then
    echo "Scratch org creation failed." >&2
    if [[ -n "${create_json:-}" ]]; then
      jq . <<< "${create_json}" >&2 || echo "${create_json}" >&2
    fi
    exit "${create_status}"
  fi

  scratch_username="$(jq -r '.result.username // .result.authFields.username // empty' <<< "${create_json}")"
  scratch_org_id="$(jq -r '.result.orgId // .result.authFields.orgId // empty' <<< "${create_json}")"
fi

if [[ -z "${scratch_username}" ]]; then
  echo "Could not determine the scratch org username." >&2
  exit 1
fi

echo "Scratch org ready: ${scratch_alias} (${scratch_username})."
if [[ -n "${scratch_org_id}" ]]; then
  echo "Org Id: ${scratch_org_id}"
fi

if [[ "${skip_data_cloud_provisioning}" != "true" ]]; then
  provision_data_cloud "${scratch_alias}"
else
  echo "Skipping Data Cloud provisioning."
fi

if [[ "${skip_metadata}" != "true" ]]; then
  echo "Deploying all metadata from ${metadata_source_dir}."
  sf project deploy start \
    --source-dir "${metadata_source_dir}" \
    --target-org "${scratch_alias}" \
    --wait 30 \
    --json \
    | jq -e '.result.success == true' >/dev/null
  echo "Metadata deploy succeeded."
else
  echo "Skipping metadata deployment."
fi

if [[ "${skip_permissions}" != "true" ]]; then
  assign_permission_set_licenses "${scratch_alias}" "${scratch_username}"
  assign_permission_sets "${scratch_alias}" "${scratch_username}"
else
  echo "Skipping permission set assignment."
fi

if [[ "${skip_agent_user}" != "true" ]]; then
  ensure_agent_user "${scratch_alias}"
else
  echo "Skipping Service Agent user creation."
fi

if [[ "${skip_data}" != "true" ]]; then
  echo "Importing data from ${data_dir}."
  node scripts/fsc-data-migration/migrate.mjs import \
    --target "${scratch_alias}" \
    --input "${data_dir}"
  echo "Data import completed."
else
  echo "Skipping data import."
fi

if [[ "${skip_files}" != "true" ]]; then
  echo "Uploading files to Account '${account_name}'."
  scripts/upload-kiran-singh-files.sh "${scratch_alias}" "${account_name}"
  echo "File import completed."
else
  echo "Skipping file import."
fi

echo "Verifying primary records."
sf data query \
  --query "SELECT Id, Name FROM Account WHERE Name = '${account_name//\'/\\\'}'" \
  --target-org "${scratch_alias}" \
  --json \
  | jq -r '"Account matches: \(.result.totalSize)"'

if [[ "${skip_files}" != "true" ]]; then
  account_id="$(
    sf data query \
      --query "SELECT Id FROM Account WHERE Name = '${account_name//\'/\\\'}' LIMIT 1" \
      --target-org "${scratch_alias}" \
      --json \
      | jq -r '.result.records[0].Id // empty'
  )"
  if [[ -n "${account_id}" ]]; then
    sf data query \
      --query "SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = '${account_id}'" \
      --target-org "${scratch_alias}" \
      --json \
      | jq -r '"Linked files: \(.result.totalSize)"'
  fi
fi

cat <<SUMMARY

Org initialization complete.
Alias: ${scratch_alias}
Username: ${scratch_username}
Admin email: ${scratch_admin_email_override:-definition file or Salesforce default}
Duration: ${duration_days} day(s)
Metadata: ${metadata_source_dir}
Permissions: $([[ "${skip_permissions}" == "true" ]] && echo "skipped" || echo "assigned when available")
Service Agent user: $([[ "${skip_agent_user}" == "true" ]] && echo "skipped" || echo "${agent_username}")
Data Cloud provisioning: $([[ "${skip_data_cloud_provisioning}" == "true" ]] && echo "skipped" || echo "requested")
Data: $([[ "${skip_data}" == "true" ]] && echo "skipped" || echo "${data_dir}")
Files: $([[ "${skip_files}" == "true" ]] && echo "skipped" || echo "data/kiran-singh-files")
SUMMARY
