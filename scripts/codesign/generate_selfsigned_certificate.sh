#!/usr/bin/env bash

set -exu

certificateFile="$1"
certificatePassword="$2"

# certificate request (see https://apple.stackexchange.com/q/359997)
cat >$certificateFile.conf <<EOL
  [ req ]
  distinguished_name = req_name
  prompt = no
  [ req_name ]
  CN = Local Self-Signed
  [ extensions ]
  basicConstraints=critical,CA:false
  keyUsage=critical,digitalSignature
  extendedKeyUsage=critical,1.3.6.1.5.5.7.3.3
  1.2.840.113635.100.6.1.14=critical,DER:0500
EOL

# generate key
openssl genrsa -out $certificateFile.key 2048
# generate self-signed certificate
openssl req -x509 -new -config $certificateFile.conf -nodes -key $certificateFile.key -extensions extensions -sha256 -out $certificateFile.crt

openssl_version=$(openssl version)
# What: Detects whether the active OpenSSL CLI supports the `-legacy` flag for PKCS#12 export.
# Why: OpenSSL 3.x and 4.x+ moved RC2-40 and other legacy PKCS#12 algorithms to a legacy provider.
# Without `-legacy`, PKCS#12 export can fail or generate bundles unreadable by macOS `security import`.
# Checking `-help` dynamically rather than matching `3*` prevents breakage when running on OpenSSL 4.x+.
if openssl pkcs12 -help 2>&1 | grep -q -- "-legacy"; then
  flag="-legacy"
else
  flag=""
fi
# wrap key and certificate into PKCS12
openssl pkcs12 $flag -export -inkey $certificateFile.key -in $certificateFile.crt -out $certificateFile.p12 -passout pass:$certificatePassword
