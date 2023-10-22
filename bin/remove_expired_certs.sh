#!/usr/bin/env bash

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

# Step 6: remove expired certificates
# Keep the storage backend and CRL by periodically removing certificates that have expired and are past a certain buffer period beyond their expiration time. 
vault write pki_int/tidy tidy_cert_store=true tidy_revoked_certs=true
