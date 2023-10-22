Description
===========

A k8s deployment of vault with scripts to create a CA.

The script `bin/build_ca_in_vault.sh` follows the turtorial https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine.

It makes use of `bin/install-vault.sh` to stand a dev instance of vault up in k8s.
