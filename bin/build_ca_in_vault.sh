#!/usr/bin/env bash

source ./config.sh

_CA_COMMON_NAME=$(echo ${CA_COMMON_NAME}|sed 's/ /_/g')
_CA_NAME=$(echo ${CA_NAME}|sed 's/ /_/g')

# Create an offline Root CA (asks for passphrase entry)
certstrap init \
     --organization "${CA_ORG}" \
     --organizational-unit "${CA_ORG_UNIT}" \
     --country "${CA_COUNTRY}" \
     --province "${CA_PROVINCE}" \
     --locality "${CA_LOCALITY}" \
     --common-name "$CA_NAME"

# Inspect offline Root CA
openssl x509 -in out/${_CA_NAME}.crt -noout  -subject -issuer

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

export VAULT_ADDR=http://127.0.0.1:8200

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

envsubst < test_org_ica1.template > terraform/test_org_ica1.tf
cd terraform
terraform init
terraform apply -auto-approve

# Get the ICA1 CSR from the Terraform state file and store it in the  csr folder.
terraform show -json | jq '.values["root_module"]["resources"][].values.csr' -r | grep -v null > csr/${_CA_COMMON_NAME}.csr

# Make sure soft link to ../out is there§
ln -s ../out out

# Sign ICA1 CSR with the offline Root CA.
certstrap sign \
     --expires "$CERT_LENGTH" \
     --csr csr/${_CA_COMMON_NAME}.csr \
     --cert out/${_CA_COMMON_NAME}.crt \
     --intermediate \
     --path-length "1" \
     --CA "${CA_NAME}" \
     "${CA_COMMON_NAME}"

# Append offline Root CA at the end of ICA1 cert to create CA chain
cat out/${_CA_COMMON_NAME}.crt out/${_CA_NAME}.crt > cacerts/test_org_v1_ica1_v1.crt

# Update the Terraform code to set the signed cert for ICA1 in Vault.
cat >> test_org_ica1.tf << EOF

resource "vault_pki_secret_backend_intermediate_set_signed" "test_org_v1_ica1_v1_signed_cert" {
 depends_on   = [vault_mount.test_org_v1_ica1_v1]
 backend      = vault_mount.test_org_v1_ica1_v1.path

 certificate = file("\${path.module}/cacerts/test_org_v1_ica1_v1.crt")
}

EOF

terraform apply -auto-approve

