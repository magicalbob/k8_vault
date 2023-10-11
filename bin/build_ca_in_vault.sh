#!/usr/bin/env bash

source ./config.sh

# Create an offline Root CA (asks for passphrase entry)
certstrap init \
     --organization "${CA_ORG}" \
     --organizational-unit "${CA_ORG_UNIT}" \
     --country "${CA_COUNTRY}" \
     --province "${CA_PROVINCE}" \
     --locality "${CA_LOCALITY}" \
     --common-name "$CA_COMMON_NAME"

# Inspect offline Root CA
openssl x509 -in out/Testing_Root.crt -noout  -subject -issuer

# Start Vault
