#!/usr/bin/env bash

# Check if both common_name and issuer_name arguments are provided
if [ $# -ne 2 ]; then
  echo "Usage: $0 <common_name> <issuer_name>"
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

# Extract common_name and issuer_name from command-line arguments
common_name="$1"
issuer_name="$2"

# Check if common_name and issuer_name are not empty
if [ -z "$common_name" ] || [ -z "$issuer_name" ]; then
  echo "Both common_name and issuer_name must be provided."
  exit 1
fi

# Step 7: rotate root CA
# To begin learning about this capability, enable another root CA in the existing PKI secrets engine mount using the new rotate feature.
vault write pki/root/rotate/internal \
    common_name="${common_name}" \
    issuer_name="${issuer_name}"

# You can also list the issuers to confirm the addition of the new Root CA.
vault list pki/issuers

# Create a role for the new example.com root CA; creating this role allows for specifying an issuer when necessary. This also provides a simple way to transition from one issuer to another by referring to it by name.
vault write pki/roles/2024-servers allow_any_name=true
