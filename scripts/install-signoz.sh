#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

VALUES_FILE="${SCRIPT_DIR}/../observability/values.yaml"

echo "${VALUES_FILE}"

helm install signoz signoz/signoz \
  --namespace monitoring --create-namespace \
  --wait \
  --timeout 1h \
  -f "$VALUES_FILE"
