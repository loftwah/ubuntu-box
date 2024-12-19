# Detailed Explanation of `docker-compose.yml`

This `docker-compose.yml` defines a service named **`ubuntu-box`** configured to provide a development environment with various utilities and language runtimes. Below is a comprehensive explanation of its components, along with extended examples for advanced use cases.

---

### **Services**

#### `ubuntu-box`

- **`build`**:

  - **`context`**: Specifies the build directory containing the `Dockerfile` (in this case, the current directory `.`).
  - **`dockerfile`**: Points to the Dockerfile that defines the environment setup.

- **`volumes`**:

  - Maps local directories or files to container paths for sharing data and configuration:
    - `.:/app`: Mounts the current directory into `/app` inside the container.
    - `~/.aws:/root/.aws:ro`: Mounts AWS credentials as read-only for use inside the container.
    - `~/.ssh:/root/.ssh:ro`: Mounts SSH credentials as read-only, enabling secure access to servers.
    - `uv_cache:/root/.cache/uv`: Stores cache data for the `uv` tool persistently.
    - `bun_cache:/root/.bun/install/cache`: Caches Bun installation files persistently.
    - `go_cache:/go/pkg/mod`: Caches Go modules persistently to avoid repeated downloads.

- **`environment`**:

  - Defines environment variables:
    - `AWS_DEFAULT_REGION`: Sets the AWS region for CLI operations (default is `ap-southeast-2`).
    - `DEBIAN_FRONTEND`: Prevents prompts during package installation by setting it to `noninteractive`.
    - `PATH`: Extends the system `PATH` variable to include paths for Python virtual environments, Go binaries, and Bun binaries.

- **`ports`**:

  - Maps host ports to container ports for services:
    - `3000:3000`: For Node.js/Bun applications.
    - `8000:8000`: For Python applications.
    - `9000:9000`: For Go applications.

- **`tty`**: Ensures the container allocates a pseudo-TTY for an interactive session.
- **`stdin_open`**: Keeps standard input open for use with interactive commands like `/bin/bash`.
- **`command`**: Overrides the default command, launching a Bash shell (`/bin/bash`).
- **`container_name`**: Sets the container name to `ubuntu-box-2025`.

---

### **Volumes**

- **`uv_cache`**: Persistent storage for `uv` tool cache.
- **`bun_cache`**: Persistent storage for Bun's cache.
- **`go_cache`**: Persistent storage for Go modules.

---

## Additional Examples for Docker Compose Configurations

### **Example 1: Networking Tools Suite**

This example creates a container optimised for running `nmap`, `traceroute`, and `tcpdump`:

```yaml
services:
  network-tools:
    image: ubuntu:24.04
    build:
      context: .
      dockerfile: Dockerfile
    network_mode: "host" # Allows direct interaction with the host's network stack.
    privileged: true # Required for low-level access to network interfaces.
    command: ["/bin/bash"]
    tty: true
    stdin_open: true
```

- **Use Cases**:
  - Run network scans using `nmap`.
  - Trace network routes with `traceroute`.
  - Capture network traffic using `tcpdump`.

#### **Commands**:

1. Start the container:
   ```bash
   docker-compose -f docker-compose.network.yml up
   ```
2. Use tools inside the container:
   ```bash
   nmap -sS 192.168.1.1
   traceroute google.com
   tcpdump -i eth0
   ```

---

### **Example 2: Multi-Service Application with Proxy**

This example demonstrates how to set up an application with an NGINX reverse proxy:

```yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8000:8000" # Application port

  proxy:
    image: nginx:latest
    ports:
      - "8080:80" # Proxy port
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
```

- **Use Cases**:
  - Serve an application through an NGINX proxy.
  - Redirect traffic or add load balancing for scalability.

---

### **Example 3: Distributed Testing Environment**

This setup uses `locust` for load testing across multiple distributed workers:

```yaml
services:
  locust-master:
    image: locustio/locust
    command: ["--master"]
    ports:
      - "8089:8089" # Web interface for monitoring tests

  locust-worker:
    image: locustio/locust
    command: ["--worker", "--master-host=locust-master"]
```

- **Use Cases**:
  - Conduct load testing for web applications.
  - Scale testing with multiple worker containers.

---

### **Example 4: Data Processing with Python**

This example sets up a Python environment with dependencies for data processing:

```yaml
services:
  data-processor:
    build:
      context: .
      dockerfile: Dockerfile
    volumes:
      - ./data:/app/data
    command: ["python3", "/app/process.py"]
```

- **Use Cases**:
  - Automate data processing pipelines.
  - Run periodic data analysis scripts.

---

### **Best Practices for Compose Files**

1. **Remove Deprecated `version` Field**:
   - Docker Compose no longer requires the `version` field for files.
2. **Use `.env` for Environment Variables**:
   - Externalise environment-specific variables for flexibility.
3. **Define Networks Explicitly**:
   - Use named networks for better control over inter-service communication.

---

### Next Steps

- Review and customise these examples for your specific use cases.
- Use `docker-compose up` to launch services as needed.
- Extend and modularise Compose files for complex setups.
