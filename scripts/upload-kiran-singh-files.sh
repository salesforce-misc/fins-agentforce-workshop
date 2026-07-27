#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <target-org-alias-or-username> [account-name]" >&2
  echo "Example: $0 my-scratch-org \"Kiran Singh\"" >&2
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 1
fi

TARGET_ORG="$1"
ACCOUNT_NAME="${2:-Kiran Singh}"
API_VERSION="v66.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FILES_DIR="${PROJECT_DIR}/data/kiran-singh-files"

for command_name in sf jq curl base64; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
done

if [[ ! -d "${FILES_DIR}" ]]; then
  echo "Files directory not found: ${FILES_DIR}" >&2
  exit 1
fi

shopt -s nullglob
files=("${FILES_DIR}"/*)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "No files found in ${FILES_DIR}" >&2
  exit 1
fi

ORG_JSON="$(sf org display --target-org "${TARGET_ORG}" --verbose --json)"
ACCESS_TOKEN="$(jq -r '.result.accessToken // empty' <<< "${ORG_JSON}")"
INSTANCE_URL="$(jq -r '.result.instanceUrl // empty' <<< "${ORG_JSON}")"

if [[ -z "${ACCESS_TOKEN}" || -z "${INSTANCE_URL}" ]]; then
  echo "Could not read auth details for target org: ${TARGET_ORG}" >&2
  exit 1
fi

escaped_account_name="${ACCOUNT_NAME//\'/\\\'}"
soql="SELECT Id, Name FROM Account WHERE Name = '${escaped_account_name}'"
encoded_soql="$(jq -rn --arg q "${soql}" '$q | @uri')"

account_response="$(
  curl --fail --silent --show-error \
    --header "Authorization: Bearer ${ACCESS_TOKEN}" \
    "${INSTANCE_URL}/services/data/${API_VERSION}/query?q=${encoded_soql}"
)"

account_count="$(jq -r '.totalSize' <<< "${account_response}")"
if [[ "${account_count}" != "1" ]]; then
  echo "Expected exactly one Account named '${ACCOUNT_NAME}' in ${TARGET_ORG}, found ${account_count}." >&2
  exit 1
fi

account_id="$(jq -r '.records[0].Id' <<< "${account_response}")"
echo "Uploading ${#files[@]} file(s) to Account '${ACCOUNT_NAME}' (${account_id}) in ${TARGET_ORG}."

for file_path in "${files[@]}"; do
  file_name="$(basename "${file_path}")"
  title="${file_name%.*}"
  version_data="$(base64 < "${file_path}" | tr -d '\n')"

  payload="$(
    jq -n \
      --arg title "${title}" \
      --arg path_on_client "${file_name}" \
      --arg first_publish_location_id "${account_id}" \
      --arg version_data "${version_data}" \
      '{
        Title: $title,
        PathOnClient: $path_on_client,
        FirstPublishLocationId: $first_publish_location_id,
        VersionData: $version_data
      }'
  )"

  create_response="$(
    curl --fail --silent --show-error \
      --request POST \
      --header "Authorization: Bearer ${ACCESS_TOKEN}" \
      --header "Content-Type: application/json" \
      --data "${payload}" \
      "${INSTANCE_URL}/services/data/${API_VERSION}/sobjects/ContentVersion"
  )"

  content_version_id="$(jq -r '.id' <<< "${create_response}")"
  echo "Uploaded ${file_name} as ContentVersion ${content_version_id}."
done

echo "Done."
