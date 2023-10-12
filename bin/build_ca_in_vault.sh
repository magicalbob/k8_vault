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
