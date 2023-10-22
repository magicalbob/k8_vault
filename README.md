Description
===========

A k8s deployment of vault with scripts to create a CA.

The script `bin/build_ca_in_vault.sh` follows the turtorial https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine.

It makes use of `bin/install-vault.sh` to stand a dev instance of vault up in k8s.

Script `bin/request_cert.sh` takes parameters `common_name` and `ttl`. It outputs the certificate issued by vault.

Script `bin/revoke_cert.sh` takes the parameter `serial_number`. This can be obtained from the cert file using the `-serial` arg of `openssl` (remember to make it lowercase and insert a colon between each 2 digits).
