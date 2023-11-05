# GrizzlyTunnel

This script is designed to set up TUN/TAP adapters and routes for creating a VPN-like network connection between a controlled system and a compromised system. It simplifies the process of configuring network routes and adapters on both systems. The controlled system and compromised system can communicate with each other through the created TUN/TAP adapters and specified routes.

## Table of Contents

- [Introduction](#introduction)
- [Usage](#usage)
- [Options](#options)
- [Examples](#examples)
- [Cleaning Up](#cleaning-up)
- [Requirements](#requirements)
- [Contributing](#contributing)

## Introduction

This script facilitates the setup of a controlled system and a compromised system for network communication. The controlled system, often acting as the server, controls the VPN connection, while the compromised system, acting as the client, connects to the controlled system through a TUN/TAP adapter.

## Usage

To use this script, you must run it with superuser privileges. It provides several options for setting up and configuring the systems. You can also use it to clean up the configurations on both systems.

1. Setup source system with routes that should be accessible trough the tunnel.
2. Setup target system defining the same routes, this will create IP table rules that tells the traffic to move from the tunnel to the nic that is connected to the target network.
3. Setup the connection using the command listed when setting up the source system. 

## Options

- `-h, --help`: Display the help menu, which provides an overview of available options and examples.
- `-s, --source`: Set up the controlled system, which controls the VPN connection.
- `-t, --target`: Set up the compromised system, which connects to the controlled system.
- `-r, --routes [route(s)]`: Add routes for network communication (required with `-s` or `-t`).
- `-at, --adapter-type`: Choose the TUN/TAP adapter type (either 'tap' or 'tun').
- `-i, --interface`: Specify the outgoing interface (default: eth0).

## Examples

- To set up the controlled system with a single route using a TAP adapter:

```bash
sudo ./GrizzlyTunnel.sh -r 10.60.1.0/24 --adapter-type tap -s
```

- To set up the controlled system with multiple routes (comma-separated):

```bash
sudo ./GrizzlyTunnel.sh -r 10.60.1.0/24,10.70.1.0/24 -s -i eth1
```

- To set up the controlled system with routes from a file:

```bash
sudo ./GrizzlyTunnel.sh -r routes.txt -s -i eth1
```

- To remove the setup on the controlled system:

```bash
sudo ./GrizzlyTunnel.sh --cleanup source
```

- To remove the setup on the compromised system:

```bash
sudo ./GrizzlyTunnel.sh --cleanup target
```


## Cleaning Up

You can use the `--cleanup` option to remove the setup on either the controlled or compromised system.

## Requirements

- This script should be run with superuser privileges (e.g., `sudo`).

## Contributing

Contributions are welcome! If you have suggestions, improvements, or feature requests, feel free to submit a pull 
