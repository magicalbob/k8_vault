#!/usr/bin/env bash

# Check if both common_name and ttl arguments are provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <serial_number>"
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

# Extract serial_number from command-line arguments
serial_number="$1"

# Check if serial_number is not empty
if [ -z "$serial_number" ]; then
  echo "serial_number must be provided."
  exit 1
fi

# Step 4: revoke certificates
# To revoke a certificate, execute the following command, replacing the <serial_number> placeholder with the actual serial number of the certificate you want to revoke.
vault write pki_int/revoke serial_number="${serial_number}"

