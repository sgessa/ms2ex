![Ms2Ex](https://raw.githubusercontent.com/sgessa/ms2ex/logo/assets/logo-light.png#gh-light-mode-only)

![Ms2Ex](https://raw.githubusercontent.com/sgessa/ms2ex/logo/assets/logo-dark.png#gh-dark-mode-only)

### MapleStory 2 Server Emulator written in Elixir

[![Elixir Version](https://img.shields.io/badge/elixir-1.20-blueviolet.svg)](https://elixir-lang.org/)
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Documentation](https://img.shields.io/badge/📚_documentation-online-brightgreen.svg)](https://sgessa.github.io/ms2ex)
[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

### 🚀 Actively Seeking Contributors! 🚀

Join us in accelerating the development of this open-source project.

See our [Contributing section](#-contributing) to get started.

## 🌟 Overview

MS2EX is an open-source server emulator for MapleStory 2, a retired Korean MMORPG.

The project aims to recreate the server infrastructure using Elixir, a functional programming language known for building scalable and fault-tolerant applications.

## ✨ Features

- **Concurrent Architecture**: Built on the Erlang VM (BEAM) for excellent handling of concurrent connections
- **Hot Code Reloading**: Update code without restarting the server
- **Fault Tolerance**: Isolated processes ensure crashes don't bring down the entire system
- **Scalable Design**: Easily scale horizontally across multiple nodes

## 🚀 Getting Started

> Prefer containers? See the [Docker installation guide](docs/DOCKER.md).

### Prerequisites

- [Elixir](https://elixir-lang.org/install.html) 1.20
- [Rust](https://www.rust-lang.org/tools/install) - Required to compile the native NIFs
- [PostgreSQL](https://www.postgresql.org/download)
- [Redis](https://redis.io/download) - Required for game client metadata

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/sgessa/ms2ex.git
   cd ms2ex
   ```

2. **Install Elixir, Erlang and Rust**

   Follow the instructions on the [Elixir installation page](https://elixir-lang.org/install.html) to install Elixir and Erlang.

   If you are using [mise](https://mise.jdx.dev) you can simply do:

   ```bash
   mise install
   ```

   `asdf` also works out of the box with the same `.tool-versions` file.

3. **Configure environment variables**
   ```bash
   # Copy the example .env file and modify if needed
   cp .env-example .env
   ```

4. **Download Game Client Metadata**

   Download the latest dump.rdb file from [GitHub Releases](https://github.com/sgessa/ms2ex/releases).

   Place it in the `priv/redis-data/` directory of the project.

5. **Set up PostgreSQL and Redis (Linux)**

   - Install and configure PostgreSQL and Redis
   - Stop Redis
   - Copy `dump.rdb` to `/var/lib/redis/dump.rdb`
   - Start Redis

6. **Install Elixir dependencies and set-up the database**
   ```bash
   mix setup
   ```

7. **Start the server**
   ```bash
   mix maple.server
   ```

## 🏗 Project Structure

```text
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
- **[Ranch](https://ninenines.eu/docs/en/ranch/2.0/guide/)** - TCP socket acceptor pool

## 🤝 Contributing

### 🔥 We Need Your Help! 🔥

**This project is actively seeking contributors to accelerate development!**

Whether you're interested in fixing bugs, adding new features, or improving documentation, your help is appreciated.

Even if you're new to Elixir or are just passionate about MapleStory 2, we welcome your contributions!

The project offers a great opportunity to learn Elixir while working on something fun.

See our [contributing guidelines](CONTRIBUTING.md) for detailed instructions on how to get started.

## 📋 Roadmap

See [docs/ROADMAP.md](docs/ROADMAP.md) for the full, prioritized roadmap of
missing features.

**Want to make an impact?** Choose an area that matches your interests and skills! Please reach out via our [Discord](https://discord.gg/DRASSfqAKk) or open an issue to discuss how you can contribute.

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- The MapleStory 2 community for their research and documentation
- Contributors to the project
- The Elixir community for their excellent tools and libraries

## 📬 Contact

For questions or to connect with the community:

- **Open an issue** on this repository for bug reports or feature requests
- **Join our [Discord](https://discord.gg/DRASSfqAKk)** - The community gathering spot for MS2 fans where you can also find MS2EX maintainers
---

<div align="center">
  <sub>Built with ❤️ by Maplers</sub>
</div>
