# Foundation PKI

Complete Public Key Infrastructure automation for certificate management and trust anchoring.

## Certificate Structure

- **Root CA:** `root/root.crt` (offline-trusted)
  - Private Key: `root/root.key`
  - Self-signed root certificate authority
  - Validity: 10 years

- **Intermediate CA:** `intermediate/intermediate.crt`
  - Private Key: `intermediate/intermediate.key`
  - CSR: `intermediate/intermediate.csr`
  - Bridges Root CA and service certificates

- **Server Certificate:** `server/server.crt`
  - Private Key: `server/server.key`
  - CSR: `server/server.csr`
  - Used for TLS/mTLS server authentication

- **Client Certificate:** `client/client.crt`
  - Private Key: `client/client.key`
  - CSR: `client/client.csr`
  - Used for mutual TLS (mTLS) client authentication

- **Trust Bundle:** `foundation-trust-bundle.pem`
  - Combined Root + Intermediate CA certificates
  - Use as trust anchor for service-to-service communication

## Usage

### Generate All PKI Artifacts
```bash
make all
```

### Generate Specific Components
```bash
make root-ca          # Generate Root CA
make intermediate-ca  # Generate Intermediate CA
make server-cert      # Generate Server Certificate
make client-cert      # Generate Client Certificate
make trust-bundle     # Generate Trust Bundle
```

### Clean Up
```bash
make clean
```

## Trust Bundle Setup

The `foundation-trust-bundle.pem` combines both root and intermediate CA certificates and serves as the trust anchor for services that need to trust Foundation-issued certificates.

### Using the Trust Bundle

**In your applications:**
```bash
# For curl
curl --cacert foundation-trust-bundle.pem https://service.example.com

# For Docker/Kubernetes
COPY foundation-trust-bundle.pem /etc/ssl/certs/
RUN update-ca-certificates
```

**In mTLS configuration:**
```yaml
tls:
  ca_cert: foundation-trust-bundle.pem
  cert: server/server.crt
  key: server/server.key
```

## GitHub Actions Automation

The included `.github/workflows/pki.yml` workflow provides:

- **Manual Trigger:** Dispatch workflow manually anytime
- **Auto-trigger:** Runs on changes to PKI-related files
- **Dependencies:** Automatically installs OpenSSL and Make
- **Artifacts:** Uploads all PKI files for download
- **Trust Bundle:** Generates combined certificate bundle

### Triggering the Workflow

**Manual dispatch:**
```
GitHub → Actions → Foundation PKI Automation → Run workflow
```

**Automatic triggers:**
- Changes to `Makefile`
- Changes to PKI directories (`root/`, `intermediate/`, `server/`, `client/`)
- Changes to workflow file itself

## Security Notes

⚠️ **Private Keys:**
- Never commit private keys to version control
- Store in secure secret management systems
- Rotate regularly in production environments

⚠️ **Trust Bundle:**
- Public certificate data only - safe to commit
- Update when certificates are renewed
- Distribute to all services that need to trust Foundation certificates

## Files

```
foundation-pki/
├── root/
│   ├── root.key                  (Private Key)
│   └── root.crt                  (Certificate)
├── intermediate/
│   ├── intermediate.key          (Private Key)
│   ├── intermediate.crt          (Certificate)
│   └── intermediate.csr          (Signing Request)
├── server/
│   ├── server.key                (Private Key)
│   ├── server.crt                (Certificate)
│   └── server.csr                (Signing Request)
├── client/
│   ├── client.key                (Private Key)
│   ├── client.crt                (Certificate)
│   └── client.csr                (Signing Request)
├── foundation-trust-bundle.pem   (Combined CA Certificates)
├── Makefile                      (Build Automation)
├── README.md                      (This file)
└── .github/
    └── workflows/
        └── pki.yml               (GitHub Actions Workflow)
```

## Documentation

For detailed PKI setup and configuration, see the Makefile targets and workflow steps.
