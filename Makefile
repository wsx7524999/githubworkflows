.PHONY: all root-ca intermediate-ca server-cert client-cert trust-bundle clean

# Default target - generates complete PKI hierarchy
all: root-ca intermediate-ca server-cert client-cert trust-bundle

# Root CA - Self-signed certificate (10 years validity)
root-ca:
	@echo "Generating Root CA..."
	@mkdir -p root
	@openssl genrsa -out root/root.key 4096
	@openssl req -x509 -new -nodes -key root/root.key \
		-sha256 -days 3650 \
		-out root/root.crt \
		-subj "/C=US/ST=State/L=City/O=Foundation/OU=Root CA/CN=Foundation Root CA"
	@echo "Root CA generated successfully"

# Intermediate CA - Signed by Root CA (5 years validity, CA:true, pathlen:0)
intermediate-ca: root-ca
	@echo "Generating Intermediate CA..."
	@mkdir -p intermediate
	@openssl genrsa -out intermediate/intermediate.key 4096
	@openssl req -new -key intermediate/intermediate.key \
		-out intermediate/intermediate.csr \
		-subj "/C=US/ST=State/L=City/O=Foundation/OU=Intermediate CA/CN=Foundation Intermediate CA"
	@echo "[ v3_intermediate_ca ]" > intermediate/intermediate.ext
	@echo "subjectKeyIdentifier = hash" >> intermediate/intermediate.ext
	@echo "authorityKeyIdentifier = keyid:always,issuer" >> intermediate/intermediate.ext
	@echo "basicConstraints = critical, CA:true, pathlen:0" >> intermediate/intermediate.ext
	@echo "keyUsage = critical, digitalSignature, cRLSign, keyCertSign" >> intermediate/intermediate.ext
	@openssl x509 -req -in intermediate/intermediate.csr \
		-CA root/root.crt -CAkey root/root.key \
		-CAcreateserial -out intermediate/intermediate.crt \
		-days 1825 -sha256 \
		-extfile intermediate/intermediate.ext \
		-extensions v3_intermediate_ca
	@rm intermediate/intermediate.csr intermediate/intermediate.ext
	@echo "Intermediate CA generated successfully"

# Server Certificate - Leaf certificate (1 year validity)
server-cert: intermediate-ca
	@echo "Generating Server Certificate..."
	@mkdir -p server
	@openssl genrsa -out server/server.key 2048
	@openssl req -new -key server/server.key \
		-out server/server.csr \
		-subj "/C=US/ST=State/L=City/O=Foundation/OU=Server/CN=server.foundation.local"
	@echo "subjectAltName = DNS:server.foundation.local,DNS:*.foundation.local,DNS:localhost" > server/server.ext
	@echo "extendedKeyUsage = serverAuth" >> server/server.ext
	@echo "keyUsage = critical, digitalSignature, keyEncipherment" >> server/server.ext
	@openssl x509 -req -in server/server.csr \
		-CA intermediate/intermediate.crt -CAkey intermediate/intermediate.key \
		-CAcreateserial -out server/server.crt \
		-days 365 -sha256 \
		-extfile server/server.ext
	@rm server/server.csr server/server.ext
	@echo "Server Certificate generated successfully"

# Client Certificate - Leaf certificate (1 year validity)
client-cert: intermediate-ca
	@echo "Generating Client Certificate..."
	@mkdir -p client
	@openssl genrsa -out client/client.key 2048
	@openssl req -new -key client/client.key \
		-out client/client.csr \
		-subj "/C=US/ST=State/L=City/O=Foundation/OU=Client/CN=client.foundation.local"
	@echo "extendedKeyUsage = clientAuth" > client/client.ext
	@echo "keyUsage = critical, digitalSignature" >> client/client.ext
	@openssl x509 -req -in client/client.csr \
		-CA intermediate/intermediate.crt -CAkey intermediate/intermediate.key \
		-CAcreateserial -out client/client.crt \
		-days 365 -sha256 \
		-extfile client/client.ext
	@rm client/client.csr client/client.ext
	@echo "Client Certificate generated successfully"

# Trust Bundle - Concatenates root + intermediate CA for trust anchoring
trust-bundle: root-ca intermediate-ca
	@echo "Generating Trust Bundle..."
	@cat root/root.crt intermediate/intermediate.crt > foundation-trust-bundle.pem
	@echo "Trust Bundle generated successfully: foundation-trust-bundle.pem"

# Clean - Removes all generated certificates and keys
clean:
	@echo "Cleaning PKI artifacts..."
	@rm -rf root/ intermediate/ server/ client/
	@rm -f foundation-trust-bundle.pem
	@echo "Clean complete"
