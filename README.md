<div align="center">
  <img src="https://github.com/your-username/ms2ex-server/raw/main/assets/logo.png" alt="MS2EX Logo" width="300"/>
  <h1>MS2EX</h1>
  <p><strong>MapleStory 2 Server Emulator written in Elixir</strong></p>

  [![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
  [![Elixir Version](https://img.shields.io/badge/elixir-~%3E%201.17-blueviolet.svg)](https://elixir-lang.org/)
  [![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg)](CONTRIBUTING.md)
</div>

## 🌟 Overview

MS2EX is an open-source server emulator for MapleStory 2, a Korean MMORPG.

The project aims to recreate the server infrastructure using Elixir, a functional programming language known for building scalable and fault-tolerant applications.

## ✨ Features

- **Concurrent Architecture**: Built on the Erlang VM (BEAM) for excellent handling of concurrent connections
- **Hot Code Reloading**: Update code without restarting the server
- **Fault Tolerance**: Isolated processes ensure crashes don't bring down the entire system
- **Scalable Design**: Easily scale horizontally across multiple nodes

## 🚀 Getting Started

### Prerequisites

- [Elixir](https://elixir-lang.org/install.html) ~> 1.17
- [PostgreSQL](https://www.postgresql.org/download/)
- [Redis](https://redis.io/download)
- LuaJIT dependencies

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

2. **Install Lua dependencies**
   ```bash
   # For Ubuntu/Debian
   apt install libluajit-5.1-dev

   # For OSX
   brew install luajit
   ```

3. **Install Elixir dependencies and set-up the database**
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

## 📚 Documentation

Detailed documentation can be found in the [docs](docs/) directory.

## 🤝 Contributing

Contributions are warmly welcomed!

Whether you're interested in fixing bugs, adding new features, improving documentation, or any other enhancements, your help is appreciated.

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Commit your changes**
   ```bash
   git commit -m 'Add some amazing feature'
   ```
4. **Push to the branch**
   ```bash
   git push origin feature/amazing-feature
   ```
5. **Open a Pull Request**

Please check out our [contributing guidelines](CONTRIBUTING.md) for more details.

## 📋 Roadmap

- [ ] Complete core server functionalities
- [ ] Implement all game mechanics
- [ ] Add unit and integration tests
- [ ] Create comprehensive documentation
- [ ] Develop admin interface
- [ ] Support for custom plugins

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- The MapleStory 2 community for their research and documentation
- Contributors to the project
- The Elixir community for their excellent tools and libraries

## 📬 Contact

For any questions or concerns, please open an issue on this repository or contact the project maintainers directly.

---

<div align="center">
  <sub>Built with ❤️ by the MS2EX community</sub>
</div>
