#!/bin/bash

# Define color codes
GREEN='\033[0;32m' # Green
NC='\033[0m'       # No Color

# Function to display the help menu
show_help() {
  echo "Usage: sudo $0 [OPTIONS]"
  echo "Options:"
  echo "  -h, --help             Display this help menu"
  echo "  -s, --source           Set up the controlled system"
  echo "  -t, --target           Set up the compromised system"
  echo "  -r, --routes [route(s)] Add routes (required with -s or -t)"
  echo "  -i, --interface        Specify the outgoing interface (default: eth0)"
  echo "  --cleanup [source|target]  Remove setup for controlled or compromised system"
  echo ""
  echo "Example usage:"
  echo "  To set up the controlled system with a single route:"
  echo "  sudo $0 -r 10.60.1.0/24 -s"
  echo "  To set up the target system with a single route:"
  echo "  sudo $0 -r 10.60.1.0/24 -i enps1 -t"
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
  # Check if the PermitTunnel directive is already present and uncommented
  if grep -q "^\s*PermitTunnel yes" /etc/ssh/sshd_config; then
    echo "[+] SSH configuration already includes PermitTunnel yes"
  else
    # Remove any commented-out PermitTunnel directive and add the active one
    sed -i '/^#\?PermitTunnel/d' /etc/ssh/sshd_config
    echo "PermitTunnel yes" >> /etc/ssh/sshd_config
    echo "[+] Added PermitTunnel yes to SSH configuration on the controlled system"
  fi

  # Check if the ClientAliveInterval directive is present and remove it if found
  if grep -q "^\s*ClientAliveInterval" /etc/ssh/sshd_config; then
    sed -i '/ClientAliveInterval/d' /etc/ssh/sshd_config
    echo "[+] Removed ClientAliveInterval from SSH configuration"
  fi

  # Check if the ClientAliveCountMax directive is present and remove it if found
  if grep -q "^\s*ClientAliveCountMax" /etc/ssh/sshd_config; then
    sed -i '/ClientAliveCountMax/d' /etc/ssh/sshd_config
    echo "[+] Removed ClientAliveCountMax from SSH configuration"
  fi

  # Add the ClientAliveInterval and ClientAliveCountMax directives
  echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
  echo "ClientAliveCountMax 3" >> /etc/ssh/sshd_config
  echo "[+] Added ClientAliveInterval and ClientAliveCountMax to SSH configuration on the controlled system"

  # Restart the SSH service to apply the changes
  systemctl restart ssh
  echo "[+] SSH service restarted"
}

wait_for_ssh_connection() {
  # Get the initial count of SSH connections
  initial_count=$(netstat | grep ssh | wc -l)

  while true; do
    # Get the current count of SSH connections
    current_count=$(netstat | grep ssh | wc -l)

    # Check if a new connection has been established
    if [ "$current_count" -gt "$initial_count" ]; then
      echo -e "${GREEN}[!] Connection established... Happy Hacking! :)${NC}"
      break
    fi

    sleep 1
  done
}

# Function to set up the controlled system
setup_controlled_system() {
  # Implement controlled system setup steps
  ip tuntap add dev tun1 mode tun
  ip addr add 10.10.255.2/30 dev tun1
  echo "[+] Added IP to tun1"
  ip link set dev tun1 up
  echo "[+] tun1 link is now up"
  IFS=',' read -ra route_array <<< "$routes"  # Split comma-separated routes
  for route in "${route_array[@]}"; do
    ip route add "$route" via 10.10.255.1 dev tun1
    echo "[+] Set up routing rule for route $route"
  done

  # Display additional messages
  echo "[+] Adding ICMP allow on tun1 for monitoring purposes"
  iptables -A INPUT -i tun1 -p icmp --icmp-type echo-request -j ACCEPT
  echo "[!] To complete the setup for VPN connection, on the target host, run:"
  echo "[!] sudo $0 -r <route(s)> -i <outgoing interface> -t"
  wait_for_ssh_connection
}

# Function to set up the compromised system
setup_compromised_system() {
  # Implement compromised system setup steps
  ip tuntap add dev tun0 mode tun user root

  echo "[+] Adding tuntap device tun0 for user root"
  ip addr add 10.10.255.1/30 dev tun0
  echo "[+] Adding ip address to tun0"
  ip link set dev tun0 up
  echo "[+] Activating tun0"
  modprobe tun
  echo "[+] Ran modprobe tun"
  # Check if IP forwarding is already enabled
  current_ip_forward_setting=$(sysctl -n net.ipv4.ip_forward)
  if [ "$current_ip_forward_setting" -eq 0 ]; then
    sysctl -w net.ipv4.ip_forward=1
    echo "[+] Enabled IP forwarding"
  else
    echo "[!] IP forwarding is already enabled"
  fi
  ip route add 10.10.255.2 via 10.10.255.1 dev tun0
  echo "[+] Added route for 10.10.255.2 via 10.10.255.1 dev tun0"
  IFS=',' read -ra route_array <<< "$routes"  # Split comma-separated routes
  for route in "${route_array[@]}"; do
    iptables -t nat -A POSTROUTING -d $route -o $interface -j MASQUERADE
    echo "[!] Added iptable rule for $route on $interface !"
  done

  # Create the SSH tunnel
  echo "[!] To create tunnel run:"
  echo -e "${GREEN}ssh -f -N -w 0:1 <user@target>${NC}"
}

cleanup_controlled_system() {
  if [ -n "$routes" ]; then
    # Remove added route
    echo "[-] Removed routes."
    ip route del "$routes" via 10.10.255.2 dev tun1
  fi
  # Remove TUN/TAP adapter
  ip link del tun1
  
  # Check and remove PermitTunnel setting
  if grep -q "^\s*PermitTunnel yes" /etc/ssh/sshd_config; then
    sed -i '/PermitTunnel yes/d' /etc/ssh/sshd_config
    echo "[-] Removed PermitTunnel yes from SSH configuration"
  fi

  # Check and remove ClientAliveInterval setting
  if grep -q "^\s*ClientAliveInterval" /etc/ssh/sshd_config; then
    sed -i '/ClientAliveInterval/d' /etc/ssh/sshd_config
    echo "[-] Removed ClientAliveInterval from SSH configuration"
  fi

  # Check and remove ClientAliveCountMax setting
  if grep -q "^\s*ClientAliveCountMax" /etc/ssh/sshd_config; then
    sed -i '/ClientAliveCountMax/d' /etc/ssh/sshd_config
    echo "[-] Removed ClientAliveCountMax from SSH configuration"
  fi

  # Restart the SSH service to apply the changes
  systemctl restart ssh
  echo "[!] Cleaned up the controlled system"
}

# Function to remove the setup on the compromised system
cleanup_compromised_system() {
  IFS=',' read -ra route_array <<< "$routes"  # Split comma-separated routes
  for route in "${route_array[@]}"; do
    iptables-save | grep -v "$route" | iptables-restore
    echo "[-] Removed NAT rule(s) for route(s) $route"
  done
  # Remove added route
  ip route del 10.10.255.2 via 10.10.255.1 dev tun0
  # Remove TUN/TAP adapter
  ip link del tun0
  echo "[!] Cleaned up the compromised system"
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

# Process arguments and enforce combinations
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
    -i | --interface)
      if [ -n "$2" ]; then
        interface="$2"
        shift
      else
        echo "[-] No interface specified. Using default interface: eth0."
      fi
      ;;
    -s | --source)
      source_option=true
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
      target_option=true
      if [ -z "$routes" ] || [ -z "$interface" ]; then
        echo "[-] The -t or --target option requires the -r or --routes option and the -i or --interface option."
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
