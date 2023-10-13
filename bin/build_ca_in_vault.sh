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

export VAULT_ADDR=http://0.0.0.0:8200

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

echo "Enabling the pki secrets engine..."
vault secrets enable -path=my-pki pki

# Initialize offline Root CA
echo "Initializing offline Root CA..."
vault write -format=json my-pki/root/generate/internal common_name="Testing Root" ttl=87600h | jq -r .data.certificate > Testing_Root.crt

# Generate Intermediate CA 1 (ICA1) in Vault
echo "Generating Intermediate CA 1 (ICA1)..."
vault secrets enable -path=test-org/v1/ica1/v1 pki
vault write test-org/v1/ica1/v1/intermediate/generate/internal -format=json common_name="Intermediate CA1 v1" key_type="rsa" key_bits=2048 | jq -r .data.csr > Intermediate_CA1_v1.csr

exit 0

# Sign ICA1 CSR with the offline Root CA
echo "Signing ICA1 CSR with the offline Root CA..."
vault write -format=json pki/root/sign-intermediate csr=@Intermediate_CA1_v1.csr format=pem_bundle ttl=43800h | jq -r .data.certificate > Intermediate_CA1_v1.crt

# Generate Intermediate CA 2 (ICA2) in Vault
echo "Generating Intermediate CA 2 (ICA2)..."
vault secrets enable -path=test-org/v1/ica2/v1 pki
vault write test-org/v1/ica2/v1/intermediate/generate/internal common_name="Intermediate CA2 v1" key_type="rsa" key_bits=2048 | jq -r .data.csr > Intermediate_CA2_v1.csr

# Sign ICA2 CSR with ICA1
echo "Signing ICA2 CSR with ICA1..."
vault write -format=json test-org/v1/ica1/v1/sign-intermediate csr=@Intermediate_CA2_v1.csr format=pem_bundle ttl=8760h | jq -r .data.certificate > Intermediate_CA2_v1.crt

# Create PKI roles for ICA2
echo "Creating PKI roles for ICA2..."
vault write test-org/v1/ica2/v1/roles/test-dot-com-subdomain \
  allowed_domains=test.com \
  allow_subdomains=true \
  allow_ip_sans=true \
  key_bits=2048 \
  max_ttl=1h

# Issue a client x509 certificate rooted in ICA2
echo "Issuing a client x509 certificate rooted in ICA2..."
vault write -format=json test-org/v1/ica2/v1/issue/test-dot-com-subdomain common_name=1.test.com ttl=1h | jq -r .data.certificate > client_certificate.crt

echo "Certificate Authority hierarchy creation complete."

