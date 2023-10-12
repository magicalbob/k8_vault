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

