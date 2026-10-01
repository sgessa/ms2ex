# Docker Installation

This guide covers running the project with Docker Compose. You can either run
only PostgreSQL and Redis while the server itself runs on the host with Elixir,
or run the Elixir app in Docker too.

Running the server on the host is the recommended setup for development: it
gives you code reloading and the usual `mix` tooling. The full-Docker setup
builds a production release and is meant for running the server, not for
working on it.

## Prerequisites

- [Docker & Docker Compose](https://docs.docker.com/compose)

## Services only (app on the host)

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
   mix maple.server
   ```

## Everything in Docker

> **Warning:** the Docker app image is a **production release**. It does not
> support code reloading or any other development niceties, and the image must
> be rebuilt every time a project file changes. If you intend to work on the
> project, run the server on the host instead (the "Services only" setup) to
> benefit from live code reloading and faster iteration.

The app runs in an opt-in compose profile, so the service-only steps above
keep working unchanged. Start all three containers with:

```bash
docker compose --profile app up -d --build
```

This builds the release image and runs the app with the web endpoint and all
game TCP listeners. Database migrations run automatically on startup.

Notes:

- `DB_HOST` and `REDIS_HOST` are set to point at the `postgres` and `redis`
  containers; other settings come from your `.env` file.
- `SERVER_ADDRESS` (from `.env`) is the address advertised to game clients.
  Set it to your machine's LAN IP (e.g. `192.168.1.10`) if clients connect
  from other devices — `127.0.0.1` only works for a client on the same host.

## Stopping

```bash
docker compose down              # services only
docker compose --profile app down
```

Add `-v` to also remove the PostgreSQL data volume.
