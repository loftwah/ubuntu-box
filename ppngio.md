# The Ultimate Guide to Piping Server

## A Deeply Detailed Technical Reference with Practical Demonstrations

## Table of Contents

1. [Introduction: What is Piping Server?](#introduction-what-is-piping-server)  
   1.1. [High-Level Concept](#high-level-concept)  
   1.2. [Under the Hood: Ephemeral, In-Memory Transfers](#under-the-hood-ephemeral-in-memory-transfers)
2. [No Permanent Storage: A Key Property](#no-permanent-storage-a-key-property)
3. [Setting Up Your Own Server](#setting-up-your-own-server)  
   3.1. [Local Quick Start (localhost)](#local-quick-start-localhost)  
   3.2. [Public Instance Example (ppngio)](#public-instance-example-ppngio)  
   3.3. [Production-Grade Setup with Docker Compose](#production-grade-setup-with-docker-compose)
4. [Basic Usage Examples](#basic-usage-examples)  
   4.1. [Plain Transfer (Unauthenticated, Unencrypted)](#plain-transfer-unauthenticated-unencrypted)  
   4.2. [Encrypted Transfer (Enhanced-Security)](#encrypted-transfer-enhanced-security)
5. [Demonstrations with localhost and ppng.io](#demonstrations-with-localhost-and-ppngio)  
   5.1. [Plain Text on localhost vs ppng.io](#plain-text-on-localhost-vs-ppngio)  
   5.2. [Encrypted File Transfer on localhost vs ppng.io](#encrypted-file-transfer-on-localhost-vs-ppngio)
6. [Advanced Scenarios](#advanced-scenarios)  
   6.1. [Database Backups and Restores](#database-backups-and-restores)  
   6.2. [Docker Container and Volume Migration](#docker-container-and-volume-migration)
7. [Performance and Progress Monitoring](#performance-and-progress-monitoring)
8. [Troubleshooting and Verification](#troubleshooting-and-verification)
9. [Security Best Practices](#security-best-practices)
10. [FAQ and Additional Resources](#faq-and-additional-resources)

---

## Introduction: What is Piping Server?

### High-Level Concept

Piping Server provides a simple, direct way to transfer data between endpoints using HTTP. It’s like a temporary pipe: one side sends data, the other side receives it. Once done, the “pipe” vanishes. Perfect for one-off data transfers where you don’t want long-term storage.

### Under the Hood: Ephemeral, In-Memory Transfers

**Key Point:** Piping Server is storage-free. It never writes data to disk. Instead, it holds data in memory just long enough to pass it from sender to receiver. When both sides disconnect, all in-memory data is lost. This makes it inherently transient and stateless.

---

## No Permanent Storage: A Key Property

This ephemeral design means:

- No database or file system usage for stored content.
- No lingering copies after transfer completion.
- Ideal for sensitive data, especially when combined with encryption.

Whether you’re transferring plain text or encrypted files, the server retains nothing once the connections close.

---

## Setting Up Your Own Server

### Local Quick Start (localhost)

For a quick test on your local machine:

```bash
docker run -p 8080:8080 nwtgck/piping-server
```

Now `http://localhost:8080` hosts your Piping Server. Test it:

```bash
echo "Hello from my local machine" | curl -T - http://localhost:8080/test-path
curl http://localhost:8080/test-path
```

### Public Instance Example (ppng.io)

For immediate testing without hosting:

```bash
echo "Testing via ppng.io" | curl -T - https://ppng.io/my-test
curl https://ppng.io/my-test
```

### Production-Grade Setup with Docker Compose

Below is a hardened Docker Compose configuration. Note that newer Compose versions do not require a `version` field:

```yaml
services:
  piping-server:
    image: nwtgck/piping-server:latest
    container_name: piping-server
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 1G
        reservations:
          cpus: "0.25"
          memory: 256M
    ports:
      - "8080:8080"
    networks:
      - piping_net
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    environment:
      - PIPING_SERVER_DEBUG=true
      - NODE_ENV=production
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  piping_net:
    driver: bridge
```

**Key Features:**

- **Healthcheck:** Ensures automatic restarts if the server becomes unresponsive.
- **Resource Limits:** Prevents runaway CPU/memory usage.
- **Security Options:** Reduces container privileges.
- **Logging Config:** Keeps logs under control.

---

## Basic Usage Examples

All these examples rely on the fundamental principle: **data is held only in memory and disappears after the transfer finishes.**

### Plain Transfer (Unauthenticated, Unencrypted)

Quick way to send a text file (`notes.txt`):

**Local Plain Transfer:**

```bash
curl -T notes.txt http://localhost:8080/my-notes
curl http://localhost:8080/my-notes > received-notes.txt
```

No storage is used on the server. After `received-notes.txt` is created, the server’s memory buffer is freed.

### Encrypted Transfer (Enhanced-Security)

For sensitive data, encrypt before sending:

```bash
PASSWORD=$(openssl rand -base64 32)
cat secret.pdf | openssl enc -aes-256-cbc -pbkdf2 -salt -pass pass:"$PASSWORD" | curl -T - http://localhost:8080/my-secure-data

curl http://localhost:8080/my-secure-data | openssl enc -d -aes-256-cbc -pbkdf2 -salt -pass pass:"$PASSWORD" > secret-decrypted.pdf
```

Even if someone intercepts the path, they only see encrypted bytes, and once the transfer completes, no trace remains on the server.

---

## Demonstrations with localhost and ppng.io

### Plain Text on localhost vs ppng.io

**Local:**

```bash
echo "Local plain message" | curl -T - http://localhost:8080/plain-local
curl http://localhost:8080/plain-local
```

**Public (ppng.io):**

```bash
echo "Public plain message" | curl -T - https://ppng.io/plain-public
curl https://ppng.io/plain-public
```

Both yield the same ephemeral behavior—no disk storage.

### Encrypted File Transfer on localhost vs ppng.io

**Local (Encrypted):**

```bash
PASSWORD=$(openssl rand -base64 32)
cat largefile.zip | openssl enc -aes-256-cbc -pbkdf2 -salt -pass pass:"$PASSWORD" | curl -T - http://localhost:8080/local-encrypted
curl http://localhost:8080/local-encrypted | openssl enc -d -aes-256-cbc -pbkdf2 -salt -pass pass:"$PASSWORD" > decrypted-local-largefile.zip
```

**Public (Encrypted via ppng.io):**

```bash
PASSWORD=$(openssl rand -base64 32)
cat largefile.zip | openssl enc -aes-256-cbc -pbkdf2 -salt -pass pass:"$PASSWORD" | curl -T - https://ppng.io/public-encrypted
curl https://ppng.io/public-encrypted | openssl enc -d -aes-256-cbc -pbkdf2 -salt -pass pass:"$PASSWORD" > decrypted-public-largefile.zip
```

Again, the server at either endpoint never stores data permanently.

---

## Advanced Scenarios

### Database Backups and Restores

**PostgreSQL Backup (Plain over localhost):**

```bash
pg_dump -Fc mydb | curl -T - http://localhost:8080/db-backup
curl http://localhost:8080/db-backup > mydb_backup.dump
pg_restore -d newdb mydb_backup.dump
```

**PostgreSQL Backup (Encrypted over ppng.io):**

```bash
PASSWORD=$(openssl rand -base64 32)
pg_dump -Fc mydb | openssl enc -aes-256-cbc -pbkdf2 -salt -pass pass:"$PASSWORD" | curl -T - https://ppng.io/db-enc-backup
curl https://ppng.io/db-enc-backup | openssl enc -d -aes-256-cbc -pbkdf2 -salt -pass pass:"$PASSWORD" > mydb_backup_encrypted.dump
pg_restore -d newdb mydb_backup_encrypted.dump
```

### Docker Container and Volume Migration

**Local Plain Container Migration:**

```bash
docker export my-container | curl -T - http://localhost:8080/container-migration
curl http://localhost:8080/container-migration | docker import - imported-container
```

**Public Encrypted Volume Migration:**

```bash
PASSWORD=$(openssl rand -base64 32)
docker run --rm -v myvolume:/data alpine tar cz /data | openssl enc -aes-256-cbc -pbkdf2 -salt -pass pass:"$PASSWORD" | curl -T - https://ppng.io/enc-volume
curl https://ppng.io/enc-volume | openssl enc -d -aes-256-cbc -pbkdf2 -salt -pass pass:"$PASSWORD" | docker run --rm -i -v newvolume:/data alpine tar xz -C /data
```

No persistent storage on the server side—just memory buffers that vanish after use.

---

## Performance and Progress Monitoring

For large files:

```bash
pv large.iso | gzip | curl -T - http://localhost:8080/large-transfer
curl http://localhost:8080/large-transfer | gunzip > received-large.iso
```

Use `pv` for a progress bar, `gzip` for compression, and encryption if needed. The server remains a dumb conduit—no storage used.

---

## Troubleshooting and Verification

If a transfer stalls, cancel and retry. To ensure data integrity:

```bash
sha256sum original-file.zip > checksum.txt
cat original-file.zip | curl -T - http://localhost:8080/verify-file
curl http://localhost:8080/verify-file | tee downloaded-file.zip | sha256sum
```

Check that the SHA-256 matches. No storage means the server can’t alter data afterward.

---

## Security Best Practices

- **Randomize paths:** Avoid predictable paths like `/test`. Use `openssl rand -hex 16` to create obscure paths.
- **Encrypt sensitive data:** The server never stores keys, so encryption is end-to-end.
- **Run behind HTTPS:** Use a reverse proxy (Nginx, Caddy) for TLS, ensuring encrypted transport.

---

## FAQ and Additional Resources

**Q: Does Piping Server store my data?**  
A: No, it only passes data through memory buffers.

**Q: Can I use it for large files?**  
A: Yes, but consider compression and progress tools. Memory usage scales with concurrent transfers, so plan resource limits accordingly.

**Q: Are plain vs encrypted transfers handled differently server-side?**  
A: No. The server treats all data as opaque streams. Encryption is done client-side.

**Q: Is ppng.io safe for sensitive data?**  
A: It’s a public instance, so always encrypt and use obscure paths if sending anything sensitive.

**Q: Can I integrate this into scripts and CI/CD pipelines?**  
A: Absolutely. `curl` and Piping Server make automation straightforward.

**Additional Resources:**

- [Piping Server GitHub](https://github.com/nwtgck/piping-server)
- [Public Instances and Usage](https://github.com/nwtgck/piping-server#public-instances)
- [OpenSSL for Encryption](https://www.openssl.org/docs/man1.1.1/man1/openssl-enc.html)

---

**In summary:**  
This guide provided a comprehensive exploration of Piping Server’s capabilities, focusing on its in-memory, ephemeral data handling. Whether transferring locally at `http://localhost:8080`, using a public instance like `https://ppng.io`, employing plain streams or encrypted pipelines, or deploying via Docker Compose in production—the key principle remains: no permanent storage, just a transient conduit for your data.
