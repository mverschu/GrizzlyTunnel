# GrizzlyTunnel

<img src="https://github.com/mverschu/GrizzlyTunnel/assets/69352107/047794aa-ac7e-4c35-8f07-26a8eb6154da" width="500" alt="Grizzly Tunnel Logo">


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

Run **'sudo su'** on both machines to execute as root.

Attacker machine where you need to connect to a network through another system that is actually connected to that network.

```bash
./GrizzlyTunnel.sh -r routes.txt -s
[+] Changed SSH configuration on the controlled system
[+] Added IP to tun1
[+] tun1 link is now up
[+] Set up routing rule for route 10.60.1.0/24
[+] Set up routing rule for route 10.60.36.0/24
[+] Set up routing rule for route 10.60.32.0/24
[+] Set up routing rule for route 10.60.35.0/24
[+] Set up routing rule for route 10.60.0.0/24
[+] Set up routing rule for route 10.60.34.0/24
[+] Set up routing rule for route 10.60.33.0/24
[!] To complete the setup for VPN connection, on the target host, run:
[!] sudo ./GrizzlyTunnel.sh -r <route(s)> -t -i <outgoing interface>
```

**Setup target:**

The machine that is connected to the network you want to access from the attacker (source) machine.

```bash
./GrizzlyTunnel.sh -r routes.txt -i eth0 -t
[+] Adding tuntap device tun0 for user root
[+] Adding ip address to tun0
[+] Activating tun0
[+] Ran modprobe tun
[!] IP forwarding is already enabled
[+] Added route for 10.10.255.2 via 10.10.255.1 dev tun0
[!] Added iptable rule for 10.60.1.0/24 on eth0 !
[!] Added iptable rule for 10.60.36.0/24 on eth0 !
[!] Added iptable rule for 10.60.32.0/24 on eth0 !
[!] Added iptable rule for 10.60.35.0/24 on eth0 !
[!] Added iptable rule for 10.60.0.0/24 on eth0 !
[!] Added iptable rule for 10.60.34.0/24 on eth0 !
[!] Added iptable rule for 10.60.33.0/24 on eth0 !
[!] To create tunnel run:
ssh -f -N -w 0:1 <user@target>
```

**Profit:**

After tunnel is created it is possible to use tools from attacker machine to target network using a layer 3 network.

```bash
ping 10.60.1.68
PING 10.60.1.68 (10.60.1.68) 56(84) bytes of data.
64 bytes from 10.60.1.68: icmp_seq=1 ttl=126 time=7.43 ms
64 bytes from 10.60.1.68: icmp_seq=2 ttl=126 time=8.77 ms
```

## Options

- `-h, --help`: Display the help menu, which provides an overview of available options and examples.
- `-s, --source`: Set up the controlled system, which controls the VPN connection.
- `-t, --target`: Set up the compromised system, which connects to the controlled system.
- `-r, --routes [route(s)]`: Add routes for network communication (required with `-s` or `-t`).
- `-i, --interface`: Specify the outgoing interface (default: eth0).

## Cleaning Up

You can use the `--cleanup` option to remove the setup on either the controlled or compromised system.

**Source:**

Everything that has been setup will be cleaned.

```bash
./GrizzlyTunnel.sh --cleanup source
[+] Cleaned up the controlled system
```

**Target:**

Everything that has been setup will be cleaned. The question to flush the IPTABLES NAT rules is asked to give user control.

```bash
./GrizzlyTunnel.sh --cleanup target
[?] Do you want to clear NAT iptables? (y/n) y
[+] Cleaned up the compromised system
```

## Requirements

- This script should be run with superuser privileges (e.g., `sudo`).
- The source host should have openssh-server installed.

## ToDo

- Adding support for TAP instead of tun.

## Contributing

Contributions are welcome! If you have suggestions, improvements, or feature requests, feel free to submit a pull 
