#!/usr/bin/env bash

# Create an offline Root CA
# =========================
#
# Use the certstrap tool to create the offline Root CA.
# You select a very strong password for protecting the CA key. (but you can just press enter;)

certstrap init \
     --organization "Test" \
     --organizational-unit "Test Org" \
     --country "US" \
     --province "MD" \
     --locality "Bethesda" \
     --common-name "Testing Root"

# Output should be:
# Enter passphrase (empty for no passphrase):
# Enter same passphrase again:
# Created out/Testing_Root.key (encrypted by passphrase)
# Created out/Testing_Root.crt
# Created out/Testing_Root.crl

# Inspect the offline Root CA certificate with openssl to ensure it has the expected subject.

openssl x509 -in out/Testing_Root.crt -noout  -subject -issuer

# Output should be:
# subject= /C=US/ST=DC/L=Bethesda/O=Test/OU=Test Org/CN=Testing Root
# issuer= /C=US/ST=DC/L=Bethesda/O=Test/OU=Test Org/CN=Testing Root

# The tree command outputs the out folder hierarchy.

tree out

# Output should be:
#out
#├── Testing_Root.crl
#├── Testing_Root.crt
#└── Testing_Root.key

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

# Generate ICA1 in vault

# Create main.tf file which defines vault provider.
cat > main.tf << EOF
provider "vault" {}

locals {
 default_3y_in_sec   = 94608000
 default_1y_in_sec   = 31536000
 default_1hr_in_sec = 3600
}

EOF

# Create test_org_ica1.tf file which enables and configures PKI secrets engine.

cat > test_org_ica1.tf << EOF
resource "vault_mount" "test_org_v1_ica1_v1" {
 path                      = "test-org/v1/ica1/v1"
 type                      = "pki"
 description               = "PKI engine hosting intermediate CA1 v1 for test org"
 default_lease_ttl_seconds = local.default_1hr_in_sec
 max_lease_ttl_seconds     = local.default_3y_in_sec
}

resource "vault_pki_secret_backend_intermediate_cert_request" "test_org_v1_ica1_v1" {
 depends_on   = [vault_mount.test_org_v1_ica1_v1]
 backend      = vault_mount.test_org_v1_ica1_v1.path
 type         = "internal"
 common_name  = "Intermediate CA1 v1 "
 key_type     = "rsa"
 key_bits     = "2048"
 ou           = "test org"
 organization = "test"
 country      = "US"
 locality     = "Bethesda"
 province     = "MD"
}
EOF

# To ensure the file structure is properly configured, use the tree command to view the directory.

tree

# Output should be:
#.
#├── main.tf
#├── out
#│   ├── Testing_Root.crl
#│   ├── Testing_Root.crt
#│   └── Testing_Root.key
#└── test_org_ica1.tf
#
#2 directories, 5 file

# First, initialize terraform; this downloads the necessary providers and initializes the backend.
terraform init

# Execute the apply command to configure Vault.
terraform apply -auto-approve

# Create a new csr folder.
mkdir csr

# Get the ICA1 CSR from the Terraform state file and store it under a new csr folder.
terraform show -json | jq '.values["root_module"]["resources"][].values.csr' -r | grep -v null > csr/Test_Org_v1_ICA1_v1.csr

# Sign ICA1 CSR with the offline Root CA.
certstrap sign \
     --expires "3 year" \
     --csr csr/Test_Org_v1_ICA1_v1.csr \
     --cert out/Intermediate_CA1_v1.crt \
     --intermediate \
     --path-length "1" \
     --CA "Testing Root" \
     "Intermediate CA1 v1"

# Output should be:
#Enter passphrase for CA key (empty for no passphrase):
# Building intermediate
# Created out/Intermediate_CA1_v1.crt from out/Intermediate_CA1_v1.csr signed by out/Testing_Root.key


# Create the cacerts folder to store the CA chain files that will be set on the PKI endpoints in Vault.
mkdir cacerts

# Append offline Root CA at the end of ICA1 cert to create a CA chain under cacerts folder. You will use this to set the signed ICA1 in Vault.
cat out/Intermediate_CA1_v1.crt out/Testing_Root.crt > cacerts/test_org_v1_ica1_v1.crt

# Update the Terraform code to set the signed cert for ICA1 in Vault.
cat >> test_org_ica1.tf << EOF

resource "vault_pki_secret_backend_intermediate_set_signed" "test_org_v1_ica1_v1_signed_cert" {
 depends_on   = [vault_mount.test_org_v1_ica1_v1]
 backend      = vault_mount.test_org_v1_ica1_v1.path

 certificate = file("\${path.module}/cacerts/test_org_v1_ica1_v1.crt")
}

EOF

# Apply the Terraform changes to set the signed ICA1 in Vault.
terraform apply -auto-approve

# Output should be:
#...truncated...
#Enter a value: yes
#
#vault_pki_secret_backend_intermediate_set_signed.test_org_v1_ica1_v1_signed_cert: Creating...
#vault_pki_secret_backend_intermediate_set_signed.test_org_v1_ica1_v1_signed_cert: Creation complete after 0s [id=test-org/v1/ica1/v1/intermediate/set-signed]
#
#Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

# Verify the ICA1 cert in Vault.
curl -s $VAULT_ADDR/v1/test-org/v1/ica1/v1/ca/pem | openssl crl2pkcs7 -nocrl -certfile  /dev/stdin  | openssl pkcs7 -print_certs -noout

# Output should be:
#subject=/C=US/ST=MD/L=Bethesda/O=test/OU=test org/CN=Intermediate CA1 v1
#issuer=/C=US/ST=MD/L=Bethesda/O=Test/OU=Test Org/CN=Testing Root

# Verify the ICA1 CA chain in Vault.
curl -s $VAULT_ADDR/v1/test-org/v1/ica1/v1/ca_chain | openssl crl2pkcs7 -nocrl -certfile  /dev/stdin  | openssl pkcs7 -print_certs -noout

# Output should be:
#subject=/C=US/ST=MD/L=Bethesda/O=test/OU=test org/CN=Intermediate CA1 v1
#issuer=/C=US/ST=MD/L=Bethesda/O=Test/OU=Test Org/CN=Testing Root
#
#subject=/C=US/ST=MD/L=Bethesda/O=Test/OU=Test Org/CN=Testing Root
#issuer=/C=US/ST=MD/L=Bethesda/O=Test/OU=Test Org/CN=Testing Root

# Your directory structure should now resemble the example output.
tree

# Output should be:
#.
#├── cacerts
#│   └── test_org_v1_ica1_v1.crt
#├── csr
#│   └── Test_Org_v1_ICA1_v1.csr
#├── main.tf
#├── out
#│   ├── Intermediate_CA1_v1.crt
#│   ├── Testing_Root.crl
#│   ├── Testing_Root.crt
#│   └── Testing_Root.key
#├── terraform.tfstate
#├── terraform.tfstate.backup
#└── test_org_ica1.tf
#
#4 directories, 10 files
