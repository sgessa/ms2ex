# Game Client Metadata

MS2EX requires game client metadata to function properly.

## Metadata System Overview

For those interested in extending or modifying the metadata, here's how the system works:

1. **Source Data**: The original game client XML files contain crucial game data.

2. **Parsing & Organization**: [Maple2](https://github.com/AngeloTadeucci/Maple2) (a C# emulator) parses these XML files and stores them in a structured format in their MySQL database.

3. **Redis Export**: [Ms2ex.File](https://github.com/sgessa/ms2ex-file) reads the organized data from Maple2 database and exports it to Redis.

4. **Server Usage**: MS2EX server reads the metadata from Redis at runtime.

## Advanced Setup (For Metadata Development)

If you need to extend or modify the metadata:

1. **Set up Maple2 with MySQL**:
   - Follow the instructions in [Maple2](https://github.com/AngeloTadeucci/Maple2) to parse client XML files into MySQL
   - Ensure the MySQL database is properly seeded with game metadata

2. **Use Ms2ex.File to export to Redis**:
   - Clone the [Ms2ex.File repository](https://github.com/icr4/ms2ex_file)
   - Follow the instructions in its README to connect to your MySQL database
   - Run the export process to transfer data to your Redis instance

3. **Configure MS2EX to use Redis**:
   - Ensure your Redis connection settings in `config/dev.exs` point to the Redis instance containing the metadata

## Troubleshooting

If MS2EX fails to start or exhibits unexpected behavior, verify that:
- Redis is running and accessible
- MS2EX's Redis connection configuration is correct
- The metadata has been correctly loaded
- For Docker setup: Make sure the `priv/redis-data/dump.rdb` file exists
- For pre-built dumps: Ensure you're using a Redis version compatible with the dump format
