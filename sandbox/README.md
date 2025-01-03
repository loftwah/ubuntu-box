# Dev Sandbox

A Docker-based development sandbox for experimenting with PostgreSQL, Redis, and other tools in a self-contained environment.

## Features

- **PostgreSQL**: A relational database for structured data.
- **Redis**: A high-performance key-value store.
- **pgAdmin**: A web-based administration tool for PostgreSQL.
- **Ubuntu**: A versatile container for testing tools and commands.

## Setup

1. Start the environment:

   ```bash
   docker compose up -d
   ```

2. Access the Ubuntu container:

   ```bash
   docker compose exec ubuntu bash
   ```

3. Install tools within the Ubuntu container (if needed):
   ```bash
   apt-get update && apt-get install postgresql-client redis-tools -y
   ```

## Usage

- **PostgreSQL**:

  - Connect from the Ubuntu container:
    ```bash
    psql -h postgres -U postgres
    ```
  - Default credentials:
    - Username: `postgres`
    - Password: `postgres`

- **Redis**:

  - Connect from the Ubuntu container:
    ```bash
    redis-cli -h redis
    ```

- **pgAdmin**:
  - Access via [http://localhost:8080](http://localhost:8080).
  - Default credentials:
    - Email: `dean@deanlofts.xyz`
    - Password: `postgres`

## Customisation

Feel free to modify `docker-compose.yml` to add more services or adjust configurations.

## Notes

- Ports for PostgreSQL and Redis are not exposed to the host for added security.
- Install additional tools in the Ubuntu container as needed for development.
