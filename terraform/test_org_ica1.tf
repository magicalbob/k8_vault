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
 common_name  = ""
 key_type     = "rsa"
 key_bits     = "2048"
 ou           = ""
 organization = ""
 country      = ""
 locality     = ""
 province     = ""
}
