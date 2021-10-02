#!/bin/sh
mkdir -p keychain
openssl genrsa -out keychain/psi.pem 4096
openssl rsa -in keychain/psi.pem -pubout > keychain/psi.pub
