#!/bin/sh
mkdir -p keychain
openssl genrsa -out keychain/xi.pem 4096
openssl rsa -in keychain/xi.pem -pubout > keychain/xi.pub
