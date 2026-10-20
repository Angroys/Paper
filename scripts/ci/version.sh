#!/usr/bin/env bash
# Emits ver=<version> to $GITHUB_OUTPUT for artifact/asset names.
# Tag push (refs/tags/v1.2.3) -> 1.2.3; anything else -> 7-char short sha.
set -euo pipefail
if [[ "${GITHUB_REF_TYPE:-}" == "tag" ]]; then
  ver="${GITHUB_REF_NAME#v}"
else
  ver="${GITHUB_SHA::7}"
fi
echo "ver=${ver}" >> "$GITHUB_OUTPUT"
echo "Version: ${ver}"
