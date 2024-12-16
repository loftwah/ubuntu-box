# Ubuntu Box 📦

A secure, feature-rich Ubuntu development environment in a Docker container. Perfect for development, testing, and CI/CD pipelines.

## Features 🚀

- **Security Tools**: lynis, fail2ban, rkhunter, AIDE, and system hardening
- **Development Runtimes**:
  - Node.js (via NVM)
  - Bun (modern JavaScript runtime & package manager)
  - Rust (with Cargo)
  - Ruby (via rbenv)
  - Go
  - Python (with poetry, pipenv, and uv)
- **Additional Tools**:
  - AWS CLI v2
  - TypeScript & ts-node
  - Git
  - Vim & Nano
  - Essential build tools

## Quick Start 🏃

```bash
# Build the image
docker build -t ubuntu-box .

# Run the container
docker run -it ubuntu-box

# Verify installation (inside container)
~/bin/verify.sh
```

## Utility Scripts 🛠️

### ubuntu_setup.sh

Sets up the environment with all necessary tools and security configurations.

### verify.sh

Verifies all installations and runs test commands for each tool.

## Security Features 🔒

- System hardening configurations
- Compiler access restrictions
- Security monitoring tools
- File integrity checking
- Intrusion detection

## Development Tools Setup 💻

### Node.js & Bun

```bash
# Node.js is installed via NVM
node --version
# Bun is ready to use
bun --version
```

### Rust

```bash
# Rust is installed with rustup
rustc --version
cargo --version
```

### Ruby

```bash
# Ruby is managed with rbenv
ruby --version
rbenv versions
```

### Go

```bash
# Go is installed and ready
go version
```

### Python

```bash
# Python tools including uv
python3 --version
uv --version
```

## File Transfer Utility 📤

Built-in support for Piping Server:

```bash
# Send files
echo 'hello, world' | curl -T - https://ppng.io/hello

# Receive files
curl https://ppng.io/hello > hello.txt
```

## Environment Configuration ⚙️

The container comes with pre-configured environment variables and paths for all installed tools. Check `~/.bashrc` for details.

## Contributing 🤝

Contributions are welcome! Please feel free to submit a Pull Request.

## Author ✍️

Dean Lofts - [dean@deanlofts.xyz](mailto:dean@deanlofts.xyz)

## License 📄

MIT License - feel free to use this in your own projects!

## Acknowledgments 👏

- Based on Ubuntu 24.04
- Inspired by modern development workflows
- Community-driven security best practices

## Support 🆘

If you encounter any issues or have questions, please [open an issue](https://github.com/loftwah/ubuntu-box/issues) on GitHub.
