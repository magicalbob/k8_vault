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

# Step 1: generate root CA

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

# Step 2: generate intermediate CA

# First, enable the pki secrets engine at the pki_int path.
vault secrets enable -path=pki_int pki

# Tune the pki_int secrets engine to issue certificates with a maximum time-to-live (TTL) of 43800 hours.
vault secrets tune -max-lease-ttl=43800h pki_int

# Execute the following command to generate an intermediate and save the CSR as pki_intermediate.csr.
vault write -format=json pki_int/intermediate/generate/internal \
     common_name="example.com Intermediate Authority" \
     issuer_name="example-dot-com-intermediate" \
     | jq -r '.data.csr' > pki_intermediate.csr

# Sign the intermediate certificate with the root CA private key, and save the generated certificate as intermediate.cert.pem.
vault write -format=json pki/root/sign-intermediate \
     issuer_ref="root-2023" \
     csr=@pki_intermediate.csr \
     format=pem_bundle ttl="43800h" \
     | jq -r '.data.certificate' > intermediate.cert.pem

# Once the CSR is signed and the root CA returns a certificate, it can be imported back into Vault.
vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem

# Step 3: create a role

# A role is a logical name that maps to a policy used to generate those credentials. It allows configuration parameters to control certificate common names, alternate names, the key uses that they are valid for, and more.

# Create a role named example-dot-com which allows subdomains, and specify the default issuer ref ID as the value of issuer_ref.
vault write pki_int/roles/example-dot-com \
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" \
     allowed_domains="example.com" \
     allow_subdomains=true \
     max_ttl="720h"

