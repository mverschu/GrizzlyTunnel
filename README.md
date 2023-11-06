# GrizzlyTunnel

This script is designed to set up TUN adapters and routes for creating a VPN-like network connection between a controlled system and a compromised system. It simplifies the process of configuring network routes and adapters on both systems. The controlled system and compromised system can communicate with each other through the created TUN adapters and specified routes.

## Table of Contents

- [Introduction](#introduction)
- [Usage](#usage)
- [Demo](#demo)
- [Options](#options)
- [Examples](#examples)
- [Cleaning Up](#cleaning-up)
- [Requirements](#requirements)
- [ToDo](#todo)
- [Contributing](#contributing)

## Introduction

This script facilitates the setup of a controlled system and a compromised system for network communication. The controlled system, often acting as the server, controls the VPN connection, while the compromised system, acting as the client, connects to the controlled system through a TUN/TAP adapter.

## Usage

To use this script, you must run it with superuser privileges. It provides several options for setting up and configuring the systems. You can also use it to clean up the configurations on both systems.

1. Setup source system with routes that should be accessible trough the tunnel.
2. Setup target system defining the same routes, this will create IP table rules that tells the traffic to move from the tunnel to the nic that is connected to the target network.
3. Setup the connection using the command listed when setting up the source system.

**Note: -s and -t should always be placed at the end of the command.**

## Demo

**Setup source:**

![image](https://github.com/mverschu/GrizzlyTunnel/assets/69352107/6a1cbd70-ac50-401c-9bdf-07efb4840b5b)

**Setup target:**

![image](https://github.com/mverschu/GrizzlyTunnel/assets/69352107/b4028e85-63ec-42ed-9ccd-5059d00c876a)

**Profit:**

![image](https://github.com/mverschu/GrizzlyTunnel/assets/69352107/f4af22f1-128a-4685-9e11-59daeba7395c)

## Options

- `-h, --help`: Display the help menu, which provides an overview of available options and examples.
- `-s, --source`: Set up the controlled system, which controls the VPN connection.
- `-t, --target`: Set up the compromised system, which connects to the controlled system.
- `-r, --routes [route(s)]`: Add routes for network communication (required with `-s` or `-t`).
- `-i, --interface`: Specify the outgoing interface (default: eth0).

## Cleaning Up

You can use the `--cleanup` option to remove the setup on either the controlled or compromised system.

## Requirements

- This script should be run with superuser privileges (e.g., `sudo`).

## ToDo

- Adding support for TAP instead of tun.

## Contributing

Contributions are welcome! If you have suggestions, improvements, or feature requests, feel free to submit a pull 
