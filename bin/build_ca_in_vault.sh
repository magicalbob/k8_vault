#!/usr/bin/env bash

# Start Vault
./bin/install-vault.sh

# Wait for it to be running
while true; do
  # Run the kubectl command and capture the output
  output=$(kubectl get all -n vault 2>&1)

  # Check if the output contains the target status
  if [[ $output =~ "Running" ]]; then
    break
  else
    echo "Waiting for vault..."
    sleep 5
  fi
done

# Start port-forwarding in the background and keep it running
while true; do
  kubectl port-forward deployment.apps/vault -n vault --address 0.0.0.0 8200:8200 2>&1 >/dev/null

  # Check the exit status of the previous command
  if [ $? -eq 0 ]; then
    echo "Port-forwarding is running successfully."
  else
    echo "Port-forwarding has exited with an error. Restarting..."
    sleep 5  # Wait for a few seconds before restarting
  fi
done &

export VAULT_ADDR=http://192.168.56.201:8200

# Get running pod
RUNNING_POD=$(kubectl get all -n vault|grep Running|cut -d\  -f1)

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

# Enable the pki secrets engine at the pki path.
vault secrets enable pki

# Tune the pki secrets engine to issue certificates with a maximum time-to-live (TTL) of 87600 hours.
vault secrets tune -max-lease-ttl=87600h pki

# Generate the example.com root CA, give it an issuer name, and save its certificate in the file root_2023_ca.crt.
vault write -field=certificate \
      pki/root/generate/internal \
      common_name="example.com" \
      issuer_name="root-2023" \
      ttl=87600h > root_2023_ca.crt

# List the issuer information for the root CA.
vault list pki/issuers/

# You can read the issuer with its ID to get the certificates and other metadata about the issuer. Let's skip the certificate output, but list the issuer metadata and usage information.
vault read pki/issuer/$(vault list -format=json pki/issuers/ | \
      jq -r '.[]')  | \
      tail -n 6

# Create a role for the root CA. 
vault write pki/roles/2023-servers allow_any_name=true

# Configure the CA and CRL URLs.
vault write pki/config/urls \
      issuing_certificates="$VAULT_ADDR/v1/pki/ca" \
      crl_distribution_points="$VAULT_ADDR/v1/pki/crl"
