#!/usr/bin/env bash
set -euo pipefail
PROFILE=${1:-.build/debug/codecov/default.profdata}
BUILD_DIR=$(find .build -path '*Tachikoma.build' -type d | head -n 1)
if [[ -z "$BUILD_DIR" ]]; then
  echo 'error: Could not locate Tachikoma.build. Run `swift test --enable-code-coverage` first.' >&2
  exit 1
fi
FILES=(
  Model
  Configuration
  CustomProviders
  Provider
  ProviderFactory
  OpenAICompatibleHelper
  UsageTracking
  ResponseCache
  RetryHandler
  Types
)
ARGS=()
for file in "${FILES[@]}"; do
  OBJ="$BUILD_DIR/${file}.swift.o"
  if [[ ! -f "$OBJ" ]]; then
    echo "error: missing object $OBJ" >&2
    exit 1
  fi
  ARGS+=( -object "$OBJ" )
done
xcrun llvm-cov report -instr-profile "$PROFILE" "${ARGS[@]}"
