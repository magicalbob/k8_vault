Description
===========

A k8s deployment of vault with scripts to create a CA.

The script `bin/build_ca_in_vault.sh` follows the turtorial https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine.

It makes use of `bin/install-vault.sh` to stand a dev instance of vault up in k8s.

Script `bin/request_cert.sh` takes parameters `common_name` and `ttl`. It outputs the certificate issued by vault.

Script `bin/revoke_cert.sh` takes the parameter `serial_number`. This can be obtained from the cert file using the `-serial` arg of `openssl` (remember to make it lowercase and insert a colon between each 2 digits).

Deleting
========

Run `kubectl delete ns vault` to get rid of the namespace.

The script `bin/build_ca_in_vault.sh` continues running in the background after it has finished to monitor the kubectl-portforward that it kicks off:

```
ps xa|grep vault
 142290 pts/1    S+     0:00 grep --color=auto vault
3984149 ?        S      0:00 bash ./bin/build_ca_in_vault.sh
3984151 ?        Sl     0:09 kubectl port-forward deployment.apps/vault -n vaul --address 0.0.0.0 8200:8200
```
Kill the bash and kubectl processes to tidy everything up.
