# Foundation PKI (Public Key Infrastructure)

A comprehensive PKI automation system for generating and managing a complete certificate hierarchy using GitHub Actions.

## Certificate Structure

This PKI implements a three-tier certificate hierarchy:

```
Root CA (10 years)
  └── Intermediate CA (5 years, CA:true, pathlen:0)
      ├── Server Certificate (1 year)
      └── Client Certificate (1 year)
```

### Certificate Details

| Certificate | Validity | Key Size | Purpose | Extensions |
|-------------|----------|----------|---------|------------|
| **Root CA** | 10 years | 4096-bit RSA | Trust anchor | Self-signed, CA:true |
| **Intermediate CA** | 5 years | 4096-bit RSA | Issue leaf certificates | CA:true, pathlen:0, keyCertSign |
| **Server Certificate** | 1 year | 2048-bit RSA | TLS/HTTPS server authentication | serverAuth, SAN with DNS names |
| **Client Certificate** | 1 year | 2048-bit RSA | mTLS client authentication | clientAuth, digitalSignature |

### Trust Bundle

The `foundation-trust-bundle.pem` contains the concatenated Root CA and Intermediate CA certificates. This bundle can be used as a trust anchor for applications that need to validate certificates issued by this PKI.

## Quick Start

### Generate Complete PKI

```bash
# Generate all certificates
make all

# Or generate individual components
make root-ca
make intermediate-ca
make server-cert
make client-cert
make trust-bundle
```

### Clean All Artifacts

```bash
make clean
```

## Usage Examples

### 1. HTTPS Server with curl

Use the server certificate to run an HTTPS server and connect with curl using the trust bundle:

```bash
# Start an HTTPS server (example with Python)
python3 -m http.server --bind localhost 8443 \
  --certfile server/server.crt \
  --keyfile server/server.key

# Connect using curl with the trust bundle
curl --cacert foundation-trust-bundle.pem https://localhost:8443
```

### 2. Docker Container with Custom CA

Mount the trust bundle into a Docker container to trust your internal PKI:

```bash
# Run container with trust bundle
docker run -v $(pwd)/foundation-trust-bundle.pem:/usr/local/share/ca-certificates/foundation.crt \
  alpine sh -c "update-ca-certificates && curl https://server.foundation.local"
```

Dockerfile example:

```dockerfile
FROM alpine:latest

# Copy trust bundle
COPY foundation-trust-bundle.pem /usr/local/share/ca-certificates/foundation.crt

# Update CA certificates
RUN apk add --no-cache ca-certificates && \
    update-ca-certificates

# Your application code
CMD ["your-application"]
```

### 3. Mutual TLS (mTLS) Authentication

Use both server and client certificates for mutual authentication:

#### Server Configuration (nginx example)

```nginx
server {
    listen 443 ssl;
    server_name server.foundation.local;

    # Server certificate
    ssl_certificate /path/to/server/server.crt;
    ssl_certificate_key /path/to/server/server.key;

    # Client certificate verification
    ssl_client_certificate /path/to/foundation-trust-bundle.pem;
    ssl_verify_client on;
    ssl_verify_depth 2;

    location / {
        # Only clients with valid certificates can access
        proxy_pass http://backend;
    }
}
```

#### Client Connection with curl

```bash
# Connect with client certificate for mTLS
curl --cacert foundation-trust-bundle.pem \
     --cert client/client.crt \
     --key client/client.key \
     https://server.foundation.local
```

### 4. Programming Language Examples

#### Python (requests library)

```python
import requests

# Server authentication only
response = requests.get(
    'https://server.foundation.local',
    verify='foundation-trust-bundle.pem'
)

# Mutual TLS (mTLS)
response = requests.get(
    'https://server.foundation.local',
    verify='foundation-trust-bundle.pem',
    cert=('client/client.crt', 'client/client.key')
)
```

#### Node.js (https module)

```javascript
const https = require('https');
const fs = require('fs');

const options = {
  hostname: 'server.foundation.local',
  port: 443,
  path: '/',
  method: 'GET',
  ca: fs.readFileSync('foundation-trust-bundle.pem'),
  cert: fs.readFileSync('client/client.crt'),
  key: fs.readFileSync('client/client.key')
};

https.request(options, (res) => {
  console.log('statusCode:', res.statusCode);
  res.on('data', (d) => process.stdout.write(d));
}).end();
```

#### Go

```go
package main

import (
    "crypto/tls"
    "crypto/x509"
    "io/ioutil"
    "net/http"
)

func main() {
    // Load CA cert
    caCert, _ := ioutil.ReadFile("foundation-trust-bundle.pem")
    caCertPool := x509.NewCertPool()
    caCertPool.AppendCertsFromPEM(caCert)

    // Load client cert
    cert, _ := tls.LoadX509KeyPair("client/client.crt", "client/client.key")

    // Setup HTTPS client
    client := &http.Client{
        Transport: &http.Transport{
            TLSClientConfig: &tls.Config{
                RootCAs:      caCertPool,
                Certificates: []tls.Certificate{cert},
            },
        },
    }

    resp, _ := client.Get("https://server.foundation.local")
    defer resp.Body.Close()
}
```

## Certificate Inspection

### View Certificate Details

```bash
# View Root CA
openssl x509 -in root/root.crt -text -noout

# View Intermediate CA
openssl x509 -in intermediate/intermediate.crt -text -noout

# View Server Certificate
openssl x509 -in server/server.crt -text -noout

# View Client Certificate
openssl x509 -in client/client.crt -text -noout
```

### Verify Certificate Chain

```bash
# Verify intermediate is signed by root
openssl verify -CAfile root/root.crt intermediate/intermediate.crt

# Verify server cert is signed by intermediate
openssl verify -CAfile root/root.crt -untrusted intermediate/intermediate.crt server/server.crt

# Verify client cert is signed by intermediate
openssl verify -CAfile root/root.crt -untrusted intermediate/intermediate.crt client/client.crt

# Verify using trust bundle
openssl verify -CAfile foundation-trust-bundle.pem server/server.crt
openssl verify -CAfile foundation-trust-bundle.pem client/client.crt
```

## GitHub Actions Automation

This repository includes automated PKI generation via GitHub Actions.

### Workflow Triggers

The PKI workflow (`.github/workflows/pki.yml`) runs automatically on:

- **Manual dispatch**: Trigger from GitHub Actions UI
- **File changes**: Automatically rebuilds when PKI-related files are modified:
  - `Makefile`
  - Certificate directories (`root/`, `intermediate/`, `server/`, `client/`)
  - `metadata.json`
  - Workflow file itself

### Workflow Steps

1. **Checkout**: Clone the repository
2. **Install Dependencies**: Install OpenSSL and Make
3. **Rebuild PKI**: Run `make clean` and `make all` to generate fresh certificates
4. **Generate Trust Bundle**: Create the combined trust bundle
5. **Upload Artifacts**: Store all certificates and keys as workflow artifacts

### Manual Trigger

To manually trigger the workflow:

1. Go to the **Actions** tab in GitHub
2. Select **Foundation PKI Automation** workflow
3. Click **Run workflow**
4. Download artifacts from the completed workflow run

### Artifacts

The workflow produces a `foundation-pki` artifact containing:
- `root/`: Root CA certificate and key
- `intermediate/`: Intermediate CA certificate and key
- `server/`: Server certificate and key
- `client/`: Client certificate and key
- `foundation-trust-bundle.pem`: Combined trust bundle
- `metadata.json`: Additional metadata (if present)

## Security Best Practices

### 🔐 Private Key Protection

- **Never commit private keys** to version control
- The `.gitignore` file excludes all `.key` files and certificate directories
- Store private keys securely with appropriate file permissions (0600)
- Use environment-specific keys for production

### 🔒 Certificate Management

- **Rotate certificates** before expiry:
  - Root CA: 10 years (rotate every 8-9 years)
  - Intermediate CA: 5 years (rotate every 4 years)
  - Leaf certificates: 1 year (rotate every 11 months)
- **Monitor expiration dates** and set up alerts
- **Revoke compromised certificates** immediately
- Keep a Certificate Revocation List (CRL) or use OCSP

### 🛡️ Production Deployment

- **Do not use these certificates in production** without proper security review
- **Customize the subject fields** (Country, State, Organization, etc.)
- **Use Hardware Security Modules (HSM)** for root CA key storage
- **Implement proper access controls** for CA operations
- **Audit all certificate issuance** operations
- **Use appropriate key sizes**: 4096-bit for CAs, minimum 2048-bit for leaf certificates

### 🔍 Trust Bundle Distribution

- The trust bundle (`foundation-trust-bundle.pem`) contains only public certificates
- Safe to distribute to clients and servers
- Verify trust bundle integrity using checksums
- Use secure channels for initial trust bundle distribution

### ⚠️ Common Pitfalls

1. **Private key exposure**: Never share `.key` files
2. **Subject name conflicts**: Use unique CNs for each certificate
3. **Missing SANs**: Always include Subject Alternative Names for server certs
4. **Weak algorithms**: Use SHA-256 or higher for signatures
5. **Insufficient validation**: Always verify the complete certificate chain

## File Structure

```
.
├── .github/
│   └── workflows/
│       └── pki.yml                    # GitHub Actions workflow
├── root/
│   ├── root.key                       # Root CA private key (excluded from git)
│   └── root.crt                       # Root CA certificate (excluded from git)
├── intermediate/
│   ├── intermediate.key               # Intermediate CA private key (excluded from git)
│   └── intermediate.crt               # Intermediate CA certificate (excluded from git)
├── server/
│   ├── server.key                     # Server private key (excluded from git)
│   └── server.crt                     # Server certificate (excluded from git)
├── client/
│   ├── client.key                     # Client private key (excluded from git)
│   └── client.crt                     # Client certificate (excluded from git)
├── foundation-trust-bundle.pem        # Combined CA certificates (safe to distribute)
├── Makefile                           # Build automation
├── .gitignore                         # Security exclusions
└── README.md                          # This file
```

## Troubleshooting

### "certificate verify failed" Error

```bash
# Verify certificate chain
openssl verify -CAfile foundation-trust-bundle.pem server/server.crt

# Check certificate dates
openssl x509 -in server/server.crt -noout -dates
```

### Regenerate Specific Certificate

```bash
# Regenerate only server certificate
rm -rf server/
make server-cert

# Regenerate everything
make clean
make all
```

### Certificate Expired

Certificates have fixed validity periods. Regenerate expired certificates:

```bash
make clean
make all
```

## License

This PKI implementation is provided as-is for educational and development purposes.

## Contributing

Contributions are welcome! Please ensure:
- No private keys are committed
- Documentation is updated for new features
- Security best practices are maintained

## References

- [OpenSSL Documentation](https://www.openssl.org/docs/)
- [X.509 Certificate Standards](https://tools.ietf.org/html/rfc5280)
- [TLS Best Practices](https://wiki.mozilla.org/Security/Server_Side_TLS)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
