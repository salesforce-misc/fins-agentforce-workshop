#!/usr/bin/env bash
set -euo pipefail

# Build zip-based static resources from expanded source folders under src-static.
# For each directory under src-static, we create/overwrite a corresponding
# <name>.resource zip in force-app/main/default/staticresources.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${ROOT_DIR}/src-static"
OUT_DIR="${ROOT_DIR}/force-app/main/default/staticresources"

if [ ! -d "${SRC_DIR}" ]; then
  echo "No src-static directory found at ${SRC_DIR}; nothing to build."
  exit 0
fi

mkdir -p "${OUT_DIR}"

shopt -s nullglob
for dir in "${SRC_DIR}"/*; do
  if [ -d "${dir}" ]; then
    name="$(basename "${dir}")"
    out="${OUT_DIR}/${name}.resource"
    echo "Building static resource ${out} from ${dir}"
    # Zip contents of the directory (not the directory itself) into <name>.resource
    (cd "${dir}" && zip -rq "${out}" .)

    meta="${OUT_DIR}/${name}.resource-meta.xml"
    if [ ! -f "${meta}" ]; then
      echo "Creating default metadata file ${meta}"
      cat > "${meta}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<StaticResource xmlns="http://soap.sforce.com/2006/04/metadata">
    <cacheControl>Private</cacheControl>
    <contentType>application/zip</contentType>
    <description>Auto-generated metadata for static resource ${name}.</description>
</StaticResource>
EOF
    fi
  fi
done

echo "Static resource build complete."


