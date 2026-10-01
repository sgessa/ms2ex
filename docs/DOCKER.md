# Docker Installation

This guide covers running PostgreSQL and Redis with Docker Compose while the
server itself runs on the host with Elixir.

## Prerequisites

- [Elixir](https://elixir-lang.org/install.html) 1.20
- [Docker & Docker Compose](https://docs.docker.com/compose)

## Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/sgessa/ms2ex.git
   cd ms2ex
   ```

2. **Configure environment variables**
   ```bash
   cp .env-example .env
   ```
   The default values are configured to work with the Docker Compose setup.

3. **Download Game Client Metadata**

   Download the latest dump.rdb file from
   [GitHub Releases](https://github.com/sgessa/ms2ex/releases) and place it in
   the `priv/redis-data/` directory of the project.

4. **Start PostgreSQL and Redis**
   ```bash
   docker compose up -d
   ```
   Redis loads the metadata from `priv/redis-data/dump.rdb`, and PostgreSQL
   data is stored in a named volume.

5. **Install Elixir dependencies and set up the database**
   ```bash
   mix setup
   ```

6. **Start the server**
   ```bash
   mix phx.server
   ```

## Stopping

```bash
docker compose down
```

Add `-v` to also remove the PostgreSQL data volume.
