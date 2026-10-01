# Build stage: compile deps and the release
FROM elixir:1.20-otp-29 AS build

# Rust is required to compile the native NIFs
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    MIX_ENV=prod

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential curl git \
    && curl -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.98.1 --profile minimal \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Compile deps separately for better layer caching
COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get && mix deps.compile

# Compile native crates
COPY native native
RUN mix compile

# Build the release
COPY lib lib
COPY priv priv
RUN mix release

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends libssl3 libstdc++6 openssl \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home ms2ex

WORKDIR /app
COPY --from=build --chown=ms2ex:ms2ex /app/_build/prod/ms2ex .

USER ms2ex

# Run database migrations, then start the app (web + game listeners)
CMD ["sh", "-c", "bin/ms2ex eval 'Ecto.Migrator.with_repo(Ms2ex.Repo, &Ecto.Migrator.run(&1, :up, all: true))' && bin/ms2ex start"]
