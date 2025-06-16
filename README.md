<div>
  <h1>MS2EX</h1>

  <p align="center">
    <img src="https://raw.githubusercontent.com/sgessa/ms2ex/main/assets/logo.png" alt="MS2EX Logo" width="300"/>
  </p>

  <p><strong>MapleStory 2 Server Emulator written in Elixir</strong></p>

  [![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
  [![Elixir Version](https://img.shields.io/badge/elixir-1.17-blueviolet.svg)](https://elixir-lang.org/)
  [![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg)](CONTRIBUTING.md)

  <h3>🚀 <strong>Actively Seeking Contributors!</strong> 🚀</h3>

  <p>
      Join us in accelerating the development of this open-source project.<br/>
      See our <a href="#-contributing">Contributing section</a> to get started.
  </p>
</div>

## 🌟 Overview

MS2EX is an open-source server emulator for MapleStory 2, a retired Korean MMORPG.

The project aims to recreate the server infrastructure using Elixir, a functional programming language known for building scalable and fault-tolerant applications.

## ✨ Features

- **Concurrent Architecture**: Built on the Erlang VM (BEAM) for excellent handling of concurrent connections
- **Hot Code Reloading**: Update code without restarting the server
- **Fault Tolerance**: Isolated processes ensure crashes don't bring down the entire system
- **Scalable Design**: Easily scale horizontally across multiple nodes

## 🚀 Getting Started

### Prerequisites

- [Elixir](https://elixir-lang.org/install.html) 1.17
- [Docker & Docker Compose](https://docs.docker.com/compose) (optional, but recommended)
- [PostgreSQL](https://www.postgresql.org/download)
- [Redis](https://redis.io/download) - Required for game client metadata
- LuaJIT dependencies - Required to run Game Client scripts

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/sgessa/ms2ex.git ms2ex-server
   cd ms2ex-server
   ```

2. **Install Elixir and Erlang**
   Follow the instructions on the [Elixir installation page](https://elixir-lang.org/install.html) to install Elixir and Erlang.

   If you are using `asdf` you can simply do:

   ```bash
   asdf plugin add elixir
   asdf plugin add erlang
   asdf install
   ```

3. **Install Lua dependencies**
   ```bash
   # For Ubuntu/Debian
   apt install libluajit-5.1-dev

   # For OSX
   brew install luajit
   ```

4. **Set up PostgreSQL and Redis**

   **Option A:** Using Docker (Recommended)
   ```bash
   # Download the dump.rdb file from GitHub Releases first
   # Place it in the priv/redis-data/ directory of the project

   # Start PostgreSQL and Redis with Docker Compose
   docker compose up -d
   ```
   This automatically sets up both services with the correct configuration and mounts the metadata file for Redis.

   **Option B:** Manual Setup
   - Install and configure PostgreSQL and Redis manually
   - Set up game client metadata as described in the [Game Client Metadata](#-game-client-metadata) section below

5. **Install Elixir dependencies and set-up the database**
   ```bash
   mix setup
   ```

6. **Start the server**
   ```bash
   mix run --no-halt
   ```

## 🏗 Project Structure

```
ms2ex-server/
├── config/             # Configuration files
├── lib/                # Source code
│   ├── ms2ex/          # Core game logic
│   └── ms2ex_web/      # Web interface and API endpoints
├── priv/               # Assets and database migrations
│   ├── repo/           # Database migrations and seeds
│   └── static/         # Static assets
└── test/               # Test files
```

## 🛠 Technology Stack

- **[Elixir](https://elixir-lang.org/)** - Primary programming language
- **[Phoenix](https://www.phoenixframework.org/)** - Web framework
- **[Ecto](https://hexdocs.pm/ecto/Ecto.html)** - Database wrapper and query generator
- **[PostgreSQL](https://www.postgresql.org/)** - Persistent data storage
- **[Redis](https://redis.io/)** - In-memory data structure store
- **[LuaPort](https://hexdocs.pm/luaport/api-reference.html)** - Lua integration
- **[Ranch](https://ninenines.eu/docs/en/ranch/2.0/guide/)** - TCP socket acceptor pool

## 🗄️ Game Client Metadata

MS2EX requires game client metadata to function properly.

This section explains how to set up the Redis server that stores this essential data.

### Quick Setup (Recommended)

The easiest way to get started is to use our pre-built Redis dump:

#### Option A: Using Docker Compose (Easiest)

Simply download the metadata file and place it in the right location:

1. **Download the latest Redis dump**:
   - Go to our [GitHub Releases](https://github.com/sgessa/ms2ex/releases) page
   - Download the latest `dump.rdb` file
   - Place it in the `priv/redis-data/` directory of the project

2. **Start Redis with Docker Compose**:
   ```bash
   docker compose up -d
   ```
   The compose file is configured to automatically mount the metadata file and also set up PostgreSQL.

#### Option B: Manual Redis Setup

1. **Download the latest Redis dump (rdb)**:
   - Go to our [GitHub Releases](https://github.com/sgessa/ms2ex/releases) page
   - Download the latest `dump.rdb` file

2. **Place the file in your Redis data directory**:
   - For standard Redis installs: `/var/lib/redis/dump.rdb` (Linux) or appropriate directory based on your installation
   - For local development: Place it where your Redis instance can access it
   - Alternatively, specify the file path in your Redis configuration

3. **Restart Redis** to load the dump file

### Metadata System Overview

For those interested in extending or modifying the metadata, here's how the system works:

1. **Source Data**: The original game client XML files contain crucial game data.

2. **Parsing & Organization**: [MapleServer2](https://github.com/AlanMorel/MapleServer2) (a C# emulator) parses these XML files and stores them in a structured format in their MySQL database.

3. **Redis Export**: [Ms2ex.File](https://github.com/sgessa/ms2ex-file) reads the organized data from a MySQL and exports it to Redis.

4. **Server Usage**: MS2EX server reads the metadata from Redis at runtime.

### Advanced Setup (For Metadata Development)

If you need to extend or modify the metadata:

1. **Set up MapleServer2 with MySQL**:
   - Follow the instructions in the MapleServer2 repository to parse client XML files into MySQL.
   - Ensure the MySQL database is properly seeded with game metadata.

2. **Use Ms2ex.File to export to Redis**:
   - Clone the [Ms2ex.File repository](https://github.com/sgessa/ms2ex-file)
   - Follow the instructions in its README to connect to your MySQL database
   - Run the export process to transfer data to your Redis instance

3. **Configure MS2EX to use Redis**:
   - Ensure your Redis connection settings in `config/dev.exs` point to the Redis instance containing the metadata

### Troubleshooting

If MS2EX fails to start or exhibits unexpected behavior, verify that:
- Redis is running and accessible
- MS2EX's Redis connection configuration is correct
- The metadata has been correctly loaded
- For Docker setup: Make sure the `priv/redis-data/dump.rdb` file exists
- For pre-built dumps: Ensure you're using a Redis version compatible with the dump format

## 🤝 Contributing

### 🔥 We Need Your Help! 🔥

**This project is actively seeking contributors to accelerate development!**

Whether you're interested in fixing bugs, adding new features, or improving documentation, your help is appreciated.

Even if you're new to Elixir or are just passionate about MapleStory 2, we welcome your contributions!

The project offers a great opportunity to learn Elixir while working on something fun.

See our [contributing guidelines](CONTRIBUTING.md) for detailed instructions on how to get started.

## 📋 Roadmap

- [ ] Complete core server functionalities
- [ ] Implement all game mechanics
- [ ] Add unit and integration tests
- [ ] Create comprehensive documentation
- [ ] Develop admin interface
- [ ] Support for custom plugins

**Want to make an impact?** Choose an area that matches your interests and skills! Please reach out via our [Discord](https://discord.gg/P66m7cvdJp) or open an issue to discuss how you can contribute.

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- The MapleStory 2 community for their research and documentation
- Contributors to the project
- The Elixir community for their excellent tools and libraries

## 📬 Contact

For questions or to connect with the community:

- **Open an issue** on this repository for bug reports or feature requests
- **Join the [MapleStory 2 Hub Discord](https://discord.gg/P66m7cvdJp)** - The community gathering spot for MS2 fans where you can also find MS2EX maintainers
---

<div align="center">
  <sub>Built with ❤️ by the Maplers</sub>
</div>
