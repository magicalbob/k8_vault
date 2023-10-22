#!/usr/bin/env bash

# Check if both common_name and ttl arguments are provided
if [ $# -ne 2 ]; then
  echo "Usage: $0 <common_name> <ttl>"
  exit 1
fi

# Set VAULT_ADDR and VAULT_TOKEN
export VAULT_ADDR=http://192.168.56.201:8200

# Get running pod
RUNNING_POD=$(kubectl get all -n vault | grep Running | cut -d\  -f1)

# Wait for token to be available
while true; do
  # Run the kubectl command and capture the output
  output=$(kubectl logs ${RUNNING_POD} -n vault 2>&1)

  # Check if the output contains the target status
  if [[ $output =~ "Root Token" ]]; then
    break
  else
    echo "Waiting for token..."
    sleep 5
  fi
done

export VAULT_TOKEN=$(kubectl logs $RUNNING_POD -n vault | grep "Root Token" | cut -d: -f2)

# Extract common_name and ttl from command-line arguments
common_name="$1"
ttl="$2"

# Check if common_name and ttl are not empty
if [ -z "$common_name" ] || [ -z "$ttl" ]; then
  echo "Both common_name and ttl must be provided."
  exit 1
fi

# Step 4: request certificates
# Execute the following command to request a new certificate with the provided common_name and ttl.
vault write pki_int/issue/example-dot-com common_name="$common_name" ttl="$ttl"

