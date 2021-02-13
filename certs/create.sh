#!/bin/sh

# Subject line to use in the certificate
SUBJ="/C=US/O=RemoteStash/OU=server/CN=localhost"
SUBJCA="/C=US/O=RemoteStashCA/OU=CA/CN=authority"

# First create a certificate authority
# It will require a passphrase to be used later when creating other certificate
# You can always create a new one by deleting the remotestaash-ca.key file
if [ ! -f remotestash-ca.key ]; then
    echo
    echo "Create CA key"
    echo
    openssl genrsa -des3 -out remotestash-ca.key 2048
    openssl req -x509 -new -nodes -key remotestash-ca.key -sha256 -days 3650 -out remotestash-ca.pem -subj $SUBJCA
else
    echo "Using existing remotestash-ca.key, delete to regenerate a new one"
fi

# then create a set of private/pub keys
echo
echo "Create new key/cst"
echo
openssl req -newkey rsa:2048 -new -nodes -x509 -days 3650 -keyout remotestash-key.pem -out remotestash-cert.pem -subj $SUBJ
echo
echo "Create sign request"
echo
openssl req -new -key remotestash-key.pem -out remotestash-cert.csr -subj $SUBJ
echo
echo "Sign cert"
echo
openssl x509 -req -in remotestash-cert.csr -CA remotestash-ca.pem -CAkey remotestash-ca.key -CAcreateserial -out remotestash-cert-signed.pem -days 3650 -sha256
echo
echo "Create der"
echo
openssl x509 -outform der -in remotestash-cert-signed.pem -out remotestash-cert-signed.der
openssl x509 -outform der -in remotestash-ca.pem -out remotestash-ca.der
