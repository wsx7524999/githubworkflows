.PHONY: all clean trust-bundle

all: root-ca intermediate-ca server-cert client-cert trust-bundle

root-ca:
	@echo "Generating Root CA..."
	@mkdir -p root
	openssl genrsa -out root/root.key 2048
	openssl req -new -x509 -days 3650 -key root/root.key -out root/root.crt \
		-subj "/CN=Foundation Root CA"
	@echo "Root CA generated successfully"

intermediate-ca: root-ca
	@echo "Generating Intermediate CA..."
	@mkdir -p intermediate
	openssl genrsa -out intermediate/intermediate.key 2048
	openssl req -new -key intermediate/intermediate.key -out intermediate/intermediate.csr \
		-subj "/CN=Foundation Intermediate CA"
	openssl x509 -req -in intermediate/intermediate.csr -CA root/root.crt -CAkey root/root.key \
		-CAcreateserial -out intermediate/intermediate.crt -days 1825
	@echo "Intermediate CA generated successfully"

server-cert: intermediate-ca
	@echo "Generating Server Certificate..."
	@mkdir -p server
	openssl genrsa -out server/server.key 2048
	openssl req -new -key server/server.key -out server/server.csr \
		-subj "/CN=foundation-server"
	openssl x509 -req -in server/server.csr -CA intermediate/intermediate.crt \
		-CAkey intermediate/intermediate.key -CAcreateserial -out server/server.crt -days 365
	@echo "Server certificate generated successfully"

client-cert: intermediate-ca
	@echo "Generating Client Certificate..."
	@mkdir -p client
	openssl genrsa -out client/client.key 2048
	openssl req -new -key client/client.key -out client/client.csr \
		-subj "/CN=foundation-client"
	openssl x509 -req -in client/client.csr -CA intermediate/intermediate.crt \
		-CAkey intermediate/intermediate.key -CAcreateserial -out client/client.crt -days 365
	@echo "Client certificate generated successfully"

trust-bundle: root-ca intermediate-ca
	@echo "Generating Trust Bundle..."
	cat root/root.crt intermediate/intermediate.crt > foundation-trust-bundle.pem
	@echo "Trust bundle generated: foundation-trust-bundle.pem"

clean:
	@echo "Cleaning PKI artifacts..."
	@rm -rf root/ intermediate/ server/ client/
	@rm -f foundation-trust-bundle.pem
	@echo "Clean complete"

.DEFAULT_GOAL := all
