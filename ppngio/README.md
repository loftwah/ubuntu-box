# 🚀 Piping Server Transfer Scripts

A suite of streamlined **bash scripts** leveraging the power of [Piping Server (ppng.io)](https://ppng.io) for **blazing-fast file transfers**. Choose your level of **security and functionality** whether you're sharing cat memes or encrypting top-secret plans, we've got you covered.

---

## 🛠️ The Line-Up

| **Script**                                                 | **Purpose**                            | **Security Level** |
| ---------------------------------------------------------- | -------------------------------------- | ------------------ |
| `plain-send.sh` / `plain-receive.sh`                       | Quick, basic file transfer (no frills) | 🟡 Basic           |
| `encrypted-send.sh` / `encrypted-receive.sh`               | Secure transfer with encryption        | 🟢 Better          |
| `secure-encrypted-send.sh` / `secure-encrypted-receive.sh` | Memory-safe, encrypted transfer        | 🔒 Best            |
| `db-backup-send.sh` / `db-backup-receive.sh`               | Encrypted PostgreSQL database transfer | 🟢 Better          |

---

## ⚙️ Prerequisites

Before you start transferring files like a pro, make sure your system is ready:

```bash
# Install the essentials
sudo apt install curl openssl -y

# Add this for secure-encrypted scripts (progress monitoring)
sudo apt install pv -y

# For database backup scripts
sudo apt install postgresql-client -y

# Make the scripts executable
chmod +x *.sh
```

---

## 🔥 How to Use

### **1️⃣ Plain Transfer** (No Encryption)

Perfect for non-sensitive data. Keep it simple. Keep it fast.

```bash
# Sender
./plain-send.sh myfile.txt my-transfer-path

# Receiver
./plain-receive.sh received.txt my-transfer-path
```

---

### **2️⃣ Encrypted Transfer** (Basic Encryption)

Your standard AES-256 encryption setup. Protect your files with ease.

```bash
# Sender (auto-generates a password if not provided)
./encrypted-send.sh secret.pdf my-secure-path
# Optional: Specify your password
./encrypted-send.sh secret.pdf my-secure-path "super-secret-password"

# Receiver
./encrypted-receive.sh decrypted.pdf my-secure-path "super-secret-password"
```

---

### **3️⃣ Secure Encrypted Transfer** (Maximum Security)

No temporary files. No compromises. Uses **AES-256** with **PBKDF2 key derivation** for robust protection.

```bash
# Sender
./secure-encrypted-send.sh sensitive.docx my-safe-path
# Specify password for extra control
./secure-encrypted-send.sh sensitive.docx my-safe-path "ultra-secure-password"

# Receiver
./secure-encrypted-receive.sh output.docx my-safe-path "ultra-secure-password"
```

---

### **4️⃣ Database Backup Transfer** (PostgreSQL Backups)

Encrypt and transfer database backups like a boss.

```bash
# Sender
./db-backup-send.sh mydatabase my-backup-path
# Optional: Use your own password
./db-backup-send.sh mydatabase my-backup-path "db-password"

# Receiver and Restore
./db-backup-receive.sh restored_database my-backup-path "db-password"
```

---

## 🛡️ Security Breakdown

1. **Plain Transfer** (`plain-*.sh`):

   - 🚫 No encryption
   - Direct, fast, and simple. Use for public or non-sensitive data.

2. **Encrypted Transfer** (`encrypted-*.sh`):

   - ✅ AES-256-CBC encryption with PBKDF2
   - May use temporary files during transfer.

3. **Secure Encrypted Transfer** (`secure-encrypted-*.sh`):
   - 🔒 No disk writes during transfer
   - Monitored progress with `pv`.

---

## 🌟 Pro Tips for Success

1. **Generate a Random Path**:
   ```bash
   RANDOM_PATH=$(openssl rand -hex 16)
   ```
2. **Password Best Practices**:
   - Auto-generate when possible.
   - Share passwords separately from paths.
3. **Private Servers**:
   - Use `ppng.io` by default or self-host for added control.

---

## 🛠️ Troubleshooting

1. **Transfer Fails**:

   - Is the path unique?
   - Check your network connection or `ppng.io` availability.

2. **Permissions**:

   - Verify file and database access permissions.

3. **Progress Monitoring**:
   - Use `secure-encrypted-*` scripts to track your transfer in real-time.

---

## 🏁 Example Workflow

```bash
# Generate a secure path
RANDOM_PATH=$(openssl rand -hex 16)

# Transfer a sensitive document
./secure-encrypted-send.sh important.pdf $RANDOM_PATH
# Share the path/password securely
./secure-encrypted-receive.sh retrieved.pdf $RANDOM_PATH "your-password"

# Transfer a database backup
./db-backup-send.sh mydatabase $RANDOM_PATH
./db-backup-receive.sh restored_database $RANDOM_PATH "your-password"
```

---

## 📜 License

MIT License. Use, modify, and share freely! Stay awesome.

---
