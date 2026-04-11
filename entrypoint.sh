#!/bin/sh

exitOnError(){
  # $1 must be set to $?
  status=$1
  message=$2
  [ "$message" != "" ] || message="Undefined error"
  if [ $status != 0 ]; then
    printf "\n"
    printf "[ERROR] $message, with status $status\n"
    case "$message" in
      *"Could not fetch rule set generation id: Permission denied (you must be root)"*)
          printf "Check you have added --cap-add=NET_ADMIN when creating your container\n"
          ;;
      *)
          printf "\n"
           ;;
    esac
    exit $status
  fi
}

exitIfUnset(){
  # $1 is the name of the variable to check - not the variable itself
  var="$(eval echo "\$$1")"
  if [ -z "$var" ]; then
    printf "[ERROR] Environment variable $1 is not set\n"
    exit 1
  fi
}

exitIfNotIn(){
  # $1 is the name of the variable to check - not the variable itself
  # $2 is a string of comma separated possible values
  var="$(eval echo "\$$1")"
  for value in $(echo $2 | sed "s/,/ /g")
  do
    if [ "$var" = "$value" ]; then
      return 0
    fi
  done
  printf "[ERROR] Environment variable $1 cannot be '$var' and must be one of the following: "
  for value in $(echo $2 | sed "s/,/ /g")
  do
    printf "$value "
  done
  printf "\n"
  exit 1
}

is_enabled() {
  # $1 is the value to check if it is enabled
  local value=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  echo "$value" | grep -q -E '^(true|yes|1|on|enabled)$'
}


# Define paths for iptables versions
IPTABLES_LEGACY="/usr/sbin/iptables-legacy"
IP6TABLES_LEGACY="/usr/sbin/ip6tables-legacy"
IPTABLES_NFT="/usr/sbin/iptables-nft"
IP6TABLES_NFT="/usr/sbin/ip6tables-nft"
IPTABLES_LEGACY_ALPINE="/usr/sbin/xtables-legacy-multi"
IPTABLES_NFT_ALPINE="/usr/sbin/xtables-nft-multi"

# link the lib for qbittorrent for alpine
export LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64:${LD_LIBRARY_PATH}

# get correct iptables for version
IPTABLE_VERSION=$(iptables --version 2>/dev/null | head -n1 | cut -d' ' -f2)
if [ "$LEGACY_IPTABLES"  = "true" ]; then 
  if [ "$(grep ^NAME= /etc/os-release | cut -d '=' -f 2 | tr -d '"')" = "Alpine Linux" ]; then 
    IPTABLE_VERSION=$("$IPTABLES_LEGACY_ALPINE" iptables --version 2>/dev/null | head -n1 | cut -d' ' -f2)
  else
    IPTABLE_VERSION=$("$IPTABLES_LEGACY" --version 2>/dev/null | head -n1 | cut -d' ' -f2)
  fi
else
  if [ "$(grep ^NAME= /etc/os-release | cut -d '=' -f 2 | tr -d '"')" = "Alpine Linux" ]; then 
    IPTABLE_VERSION=$("$IPTABLES_NFT_ALPINE" iptables --version 2>/dev/null | head -n1 | cut -d' ' -f2)
  else
    IPTABLE_VERSION=$("$IPTABLES_NFT" --version 2>/dev/null | head -n1 | cut -d' ' -f2)
  fi
fi

printf " =========================================\n"
printf " ============== qBittorrent ==============\n"
printf " =================== + ===================\n"
printf " ============= PIA CONTAINER =============\n"
printf " =========================================\n"
printf " OS: $(cat /etc/os-release | ack PRETTY_NAME=\"*\" | cut -d "\"" -f 2 | cut -d "\"" -f 1)\n"
printf " =========================================\n"
printf " OpenVPN version: $(openvpn --version | head -n 1 | ack "OpenVPN [0-9\.]* " | cut -d" " -f2)\n"
printf " Wireguard version: $(wg --version | head -n 1 | ack " v[0-9\.]* " | cut -d" " -f2)\n"
printf " Iptables version: $IPTABLE_VERSION\n"
printf " qBittorrent version: $(qbittorrent-nox --version | cut -d" " -f2)\n"
printf " =========================================\n"
printf "\n"

############################################
# Check Depreciated Parameters
############################################
if [ -n "$USER" ] && [ -z "$PIA_USERNAME" ]; then
  printf "[WARNING] The use of environment variable USER is depreciated.\n"
  printf " Please use PIA_USERNAME\n"
  printf " or use a secure auth.conf file instead. See the wiki for more information:\n"
  printf " https://github.com/j4ym0/pia-qbittorrent-docker/wiki/Using-the-auth.conf-file\n"
  printf "\n"
  export PIA_USERNAME=$USER
  unset -v USER
fi
if [ -n "$USERNAME" ] && [ -z "$PIA_USERNAME" ]; then
  printf "[WARNING] The use of environment variable USERNAME is depreciated.\n"
  printf " Please use PIA_USERNAME\n"
  printf " or use a secure auth.conf file instead. See the wiki for more information:\n"
  printf " https://github.com/j4ym0/pia-qbittorrent-docker/wiki/Using-the-auth.conf-file\n"
  printf "\n"
  export PIA_USERNAME=$USERNAME
  unset -v USERNAME
fi
if [ -n "$PASSWORD" ] && [ -z "$PIA_PASSWORD" ]; then
  printf "[WARNING] The use of environment variable PASSWORD is depreciated.\n"
  printf " Please use PIA_PASSWORD\n"
  printf " or use a secure auth.conf file instead. See the wiki for more information:\n"
  printf " https://github.com/j4ym0/pia-qbittorrent-docker/wiki/Using-the-auth.conf-file\n"
  printf "\n"
  export PIA_PASSWORD=$PASSWORD
  unset -v PASSWORD
fi
if [ -n "$REGION" ]; then
  printf "[WARNING] The use of environment variable REGION is depreciated.\n"
  printf " Please use PIA_REGION\n"
  printf "\n"
  export PIA_REGION=$REGION
  unset -v REGION
fi

# convert vpn to lower case for dir
server=$(echo "$PIA_REGION" | tr '[:upper:]' '[:lower:]')

############################################
# CHECK if VPN_CLIENT should be openvpn or wireguard
############################################
if [ -z $VPN_CLIENT ]; then
  printf "Defaulting to OpenVPN\n"
  VPN_CLIENT="openvpn"
fi
if [ "$VPN_Client" != "openvpn" ] && [ "$VPN_CLIENT" != "wireguard" ]; then
  VPN_CLIENT="openvpn"
fi

############################################
# CHECK PARAMETERS
############################################
cat "/openvpn/nextgen/$server.ovpn" > /dev/null
exitOnError $? "/openvpn/nextgen/$server.ovpn is not accessible"
if [ -z $WEBUI_PORT ]; then
  WEBUI_PORT=8888
fi
if [ `echo $WEBUI_PORT | ack "^[0-9]+$"` != $WEBUI_PORT ]; then
  printf "WEBUI_PORT is not a valid number\n"
  exit 1
elif [ $WEBUI_PORT -lt 1024 ]; then
  printf "WEBUI_PORT cannot be a privileged port under port 1024\n"
  exit 1
elif [ $WEBUI_PORT -gt 65535 ]; then
  printf "WEBUI_PORT cannot be a port higher than the maximum port 65535\n"
  exit 1
fi
if [ -z $VPN_LOG_DIR ]; then
  VPN_LOG_DIR=/logs
fi
if [ -z $VPN_MAX_ITERATIONS ]; then
  VPN_MAX_ITERATIONS=3
fi

############################################
# SHOW PARAMETERS
############################################
printf "System parameters:\n"
printf " * userID: $UID\n"
printf " * groupID: $GID\n"
printf " * timezone: $(date +"%Z %z")\n"
printf "VPN parameters:\n"
printf " * Region: $server\n"
printf " * VPN Client: $VPN_CLIENT\n"
printf "Local network parameters:\n"
printf " * Web UI port: $WEBUI_PORT\n"
printf " * Adding PIA DNS Servers\n"
cat /dev/null > /etc/resolv.conf
for name_server in $(echo $DNS_SERVERS | sed "s/,/ /g")
do
	echo " * * Adding $name_server to resolv.conf"
	echo "nameserver $name_server" >> /etc/resolv.conf
done

############################################
# Change Timezone
############################################
if [ -n "$TZ" ]; then
  printf "[INFO] Writing Timezone info $TZ\n"
  
  # Check if the timezone data exists
  if [ ! -f "/usr/share/zoneinfo/$TZ" ]; then
    printf "[ERROR] Timezone '$TZ' not found. Check the timezone\n"
  else
    if [ -f /etc/localtime ]; then
      printf "[WARNING] localtime file already exists! Not editing\n"
    else
      ln -sf  "/usr/share/zoneinfo/$TZ" /etc/localtime
      printf " * Updated localtime\n"
    fi
    
    if [ -f /etc/timezone ]; then
      printf "[WARNING] timezone file already exists! Not editing\n"
    else
      echo "$TZ" > /etc/timezone
      printf " * Updated timezone\n"
    fi
  fi
fi

#####################################################
# Writes to protected file and remove PIA_USERNAME, PIA_PASSWORD
# Best option is to mount a secure file using docker
# -v /auth-file.conf:/auth.conf
#####################################################
if [ -f /auth.conf ]; then
  if [ "$(wc -l < /auth.conf)" -gt 0 ] && [ "$(wc -c < /auth.conf)" -gt 10 ]; then
    printf "[INFO] /auth.conf file looks good\n"
    if [ -n "$PIA_USERNAME" ] || [ -n "$PIA_PASSWORD" ]; then
      printf "  * Using credentials from /auth.conf\n"
      printf "  * Ignoring environment variables PIA_USERNAME and PIA_PASSWORD\n"
      printf "[Warning] Please remove PIA_USERNAME and PIA_PASSWORD environment variables\n"
    fi
  else
    printf "[INFO] Please check /auth.conf file. Check line 1 is your username and line 2 is your password\n"
    exit 7
  fi
else
  # No auth file mounted creating it from environment variables
  printf "[INFO] Unable to find /auth.conf file, creating it from environment variables\n"
  exitIfUnset PIA_USERNAME
  exitIfUnset PIA_PASSWORD
  printf "[INFO] Writing PIA_USERNAME and PIA_PASSWORD to protected file /auth.conf..."
  echo "$PIA_USERNAME" > /auth.conf
  exitOnError $?
  echo "$PIA_PASSWORD" >> /auth.conf
  exitOnError $?
  chmod 400 /auth.conf
  exitOnError $?
  printf "DONE\n"
fi
# Check if user vars have been set and clear them
if [ -n "$PIA_USERNAME" ] || [ -n "$PIA_PASSWORD" ]; then
  printf "[INFO] Clearing environment variables PIA_USERNAME and PIA_PASSWORD..."
  unset -v PIA_USERNAME
  unset -v PIA_PASSWORD
  printf "DONE\n"
fi

############################################
#            VPN configuration
############################################
if [ "$VPN_CLIENT" = "wireguard" ]; then
  printf "[INFO] Configuring WireGuard VPN client...\n"

if [ -f /proc/net/if_inet6 ] && ( [ $(sysctl -n net.ipv6.conf.all.disable_ipv6) -ne 1 ] || [ $(sysctl -n net.ipv6.conf.default.disable_ipv6) -ne 1 ] ); then
    printf " * Disabling ipv6 as not supported\n"
    echo "sysctl -w net.ipv6.conf.all.disable_ipv6=1"
    echo -e "sysctl -w net.ipv6.conf.default.disable_ipv6=1${nc}"
  fi

  pia_gen=$(curl -s -u "$(sed '1!d' /auth.conf):$(sed '2!d' /auth.conf)" \
    "https://privateinternetaccess.com/gtoken/generateToken")

  if [ "$(echo "$pia_gen" | jq -r '.status')" != "OK" ]; then
    printf " [ERROR] getting token\n"
    printf " =========================================\n"
    printf " =======Check username and password=======\n"
    printf " =========================================\n"
    exit 3
  fi

  piatoken=$(echo "$pia_gen" | jq -r '.token')
  if [ ! -z $piatoken ]; then
    printf " * Got PIA token\n"
  fi

  privateKey="$(wg genkey)"
  if [ ! -z $privateKey ]; then
    printf " * Got private key\n"
  fi

  publicKey="$( echo "$privateKey" | wg pubkey)"
  if [ ! -z $publicKey ]; then
    printf " * Got Public key\n"
  fi

  if regiondata=$(jq --arg SERVER "netherlands" -er '
                  def normalize: gsub("[_-]"; " ") | ascii_downcase | gsub("\\s+"; " ");
                  ($SERVER | normalize) as $search |
                  [.regions[] | 
                  select((.name | normalize | contains($search)) or (.id | normalize | contains($search)))] |
                  if length > 0 then .[0] else empty end' /app/data.json); then
    
    printf " * Got PIA region data\n"
    
    # Extract wg_cn and wg_ip from the region data
    wg_cn=$(echo "$regiondata" | jq -r ".servers.wg | .[0].cn")
    wg_ip=$(echo "$regiondata" | jq -r ".servers.wg | .[0].ip")

    # Get wg_port from groups (this part doesn't depend on region selection)
    wg_port=$(jq -r '.groups.wg | .[0] | .ports | .[0]' /app/data.json)
    
  else
    printf "[ERROR] Getting region data, check PIA_REGION\n"
    exit 1
  fi

  WG_IP="$(echo $regiondata | jq -r '.servers.wg[0].ip')"
  WG_HOSTNAME="$(echo $regiondata | jq -r '.servers.wg[0].cn')"

  printf " * Getting wireguard config for $server...\n"
  wireguard_json="$(curl -s -G \
    --connect-to "$wg_cn::$wg_ip:" \
    --cacert "/app/ca.rsa.4096.crt" \
    --data-urlencode "pt=$piatoken" \
    --data-urlencode "pubkey=$publicKey" \
    "https://$wg_cn:$wg_port/addKey" )"

  if [ "$(echo "$wireguard_json" | jq -r '.status')" != "OK" ]; then
    printf "[ERROR] Getting wireguard Settings - $(echo "$wireguard_json" | jq -r '.status')\n"
    exit 5
  fi

  printf " * Writing Wireguard connection settings..."
  if [ ! -d /etc/wireguard ]; then
    mkdir /etc/wireguard
  fi

  # Generate PIA WireGuard config
  cat > /etc/wireguard/pia.conf <<EOF
    [Interface]
    PrivateKey = ${privateKey}
    Address = $(echo "$wireguard_json" | jq -r '.peer_ip')
    #DNS = $(echo "$wireguard_json" | jq -r '.dns_servers[0]')
    Table = off

    [Peer]
    PublicKey = $(echo "$wireguard_json" | jq -r '.server_key')
    AllowedIPs = 0.0.0.0/0
    Endpoint = ${WG_IP}:$(echo "$wireguard_json" | jq -r '.server_port')
    PersistentKeepalive = 25
EOF

  # Get VPN Server for firewall
  VPNIPS=$WG_IP
  PORT=$(echo "$wireguard_json" | jq -r '.server_port')
  printf "DONE\n"

else
  printf "[INFO] Configuring OpenVPN VPN client...\n"

  ############################################
  # CHECK FOR TUN DEVICE
  ############################################
  if [ "$(cat /dev/net/tun 2>&1 /dev/null)" != "cat: read error: File descriptor in bad state" ]; then
    printf "[WARNING] TUN device is not available, creating it..."
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200
    exitOnError $?
    chmod 0666 /dev/net/tun
    printf "DONE\n"
  fi

  ############################################
  # Reading chosen OpenVPN configuration
  ############################################
  printf " * Reading OpenVPN configuration...\n"
  CONNECTIONSTRING=$(ack 'privacy.network' "/openvpn/nextgen/$server.ovpn")
  exitOnError $?
  PORT=$(echo $CONNECTIONSTRING | cut -d' ' -f3)
  if [ "$PORT" = "" ]; then
    printf "[ERROR] Port not found for $server\n"
    exit 1
  fi
  PIADOMAIN=$(echo $CONNECTIONSTRING | cut -d' ' -f2)
  if [ "$PIADOMAIN" = "" ]; then
    printf "[ERROR] Domain not found for $server\n"
    exit 1
  fi
  printf " * Port: $PORT\n"
  printf " * Domain: $PIADOMAIN\n"
  printf " * Detecting IP addresses corresponding to $PIADOMAIN...\n"
  VPNIPS=$(dig $PIADOMAIN +short | grep '^[.0-9]*$')
  exitOnError $?
  if [ "$VPNIPS" = "" ]; then
    printf "[ERROR] Unable to connect to $PIADOMAIN"
    exit 3
  fi
  for ip in $VPNIPS; do
    printf " * * $ip\n";
  done

  ############################################
  # Writing target OpenVPN files
  ############################################
  TARGET_PATH="/openvpn/target"
  printf " * Creating target OpenVPN files in $TARGET_PATH..."
  rm -rf $TARGET_PATH/*
  cd "/openvpn/nextgen"
  cp -f *.crt "$TARGET_PATH"
  exitOnError $? "Cannot copy crt file to $TARGET_PATH"
  cp -f *.pem "$TARGET_PATH"
  exitOnError $? "Cannot copy pem file to $TARGET_PATH"
  cp -f "$server.ovpn" "$TARGET_PATH/config.ovpn"
  exitOnError $? "Cannot copy $server.ovpn file to $TARGET_PATH"
  sed -i "/$CONNECTIONSTRING/d" "$TARGET_PATH/config.ovpn"
  exitOnError $? "Cannot delete '$CONNECTIONSTRING' from $TARGET_PATH/config.ovpn"
  sed -i '/resolv-retry/d' "$TARGET_PATH/config.ovpn"
  exitOnError $? "Cannot delete 'resolv-retry' from $TARGET_PATH/config.ovpn"
  for ip in $VPNIPS; do
    echo "remote $ip $PORT" >> "$TARGET_PATH/config.ovpn"
    exitOnError $? "Cannot add 'remote $ip $PORT' to $TARGET_PATH/config.ovpn"
  done
  # Uses the username/password from this file to get the token from PIA
  echo "auth-user-pass /auth.conf" >> "$TARGET_PATH/config.ovpn"
  exitOnError $? "Cannot add 'auth-user-pass /auth.conf' to $TARGET_PATH/config.ovpn"
  # Reconnects automatically on failure
  echo "auth-retry nointeract" >> "$TARGET_PATH/config.ovpn"
  exitOnError $? "Cannot add 'auth-retry nointeract' to $TARGET_PATH/config.ovpn"
  # Prevents auth_failed infinite loops - make it interact? Remove persist-tun? nobind?
  echo "pull-filter ignore \"auth-token\"" >> "$TARGET_PATH/config.ovpn"
  exitOnError $? "Cannot add 'pull-filter ignore \"auth-token\"' to $TARGET_PATH/config.ovpn"
  echo "mssfix 1300" >> "$TARGET_PATH/config.ovpn"
  exitOnError $? "Cannot add 'mssfix 1300' to $TARGET_PATH/config.ovpn"
  echo "script-security 2" >> "$TARGET_PATH/config.ovpn"
  exitOnError $? "Cannot add 'script-security 2' to $TARGET_PATH/config.ovpn"
  #echo "up /etc/openvpn/update-resolv-conf" >> "$TARGET_PATH/config.ovpn"
  #exitOnError $? "Cannot add 'up /etc/openvpn/update-resolv-conf' to $TARGET_PATH/config.ovpn"
  #echo "down /etc/openvpn/update-resolv-conf" >> "$TARGET_PATH/config.ovpn"
  #exitOnError $? "Cannot add 'down /etc/openvpn/update-resolv-conf' to $TARGET_PATH/config.ovpn"
  # Note: TUN device re-opening will restart the container due to permissions
  printf "DONE\n"
fi

############################################
# NETWORKING
############################################
printf "[INFO] Finding network properties...\n"
printf " * Detecting default gateway..."
DEFAULT_GATEWAY=$(ip r | ack 'default via' | cut -d" " -f 3)
exitOnError $?
printf "$DEFAULT_GATEWAY\n"
printf " * Detecting local interface..."
INTERFACE=$(ip r | ack 'default via' | cut -d" " -f 5)
exitOnError $?
printf "$INTERFACE\n"
printf " * Detecting local subnet..."
SUBNET=$(ip r | ack -v 'default via' | ack $INTERFACE | tail -n 1 | cut -d" " -f 1)
exitOnError $?
printf "$SUBNET\n"
for EXTRASUBNET in $(echo $EXTRA_SUBNETS | sed "s/,/ /g")
do
  printf " * Adding $EXTRASUBNET as route via $INTERFACE..."
  ip route add $EXTRASUBNET via $DEFAULT_GATEWAY dev $INTERFACE
  exitOnError $?
  printf "DONE\n"
done
printf " * Detecting target VPN interface..."
if [ "$VPN_CLIENT" = "wireguard" ]; then
  VPN_DEVICE="pia"
else
  VPN_DEVICE=$(cat $TARGET_PATH/config.ovpn | ack 'dev ' | cut -d" " -f 2)0
fi
exitOnError $?
printf "$VPN_DEVICE\n"

############################################
# FIREWALL
############################################
printf "[INFO] Checking firewall\n"
if [ "$(readlink -f $(which iptables))" = "$IPTABLES_LEGACY" ]; then
  printf " * Current mode: Legacy\n"
  FIREWALL_MODE="legacy"
elif [ "$(readlink -f $(which iptables))" = "$IPTABLES_LEGACY_ALPINE" ]; then
  printf " * Current mode: Legacy\n"
  FIREWALL_MODE="legacy"
else
  printf " * Current mode: Normal (nftables)\n"
  FIREWALL_MODE="normal"
fi

if [ "$FIREWALL_MODE" = "legacy" ] && [ "$LEGACY_IPTABLES" = "true" ]; then
  printf " * iptables set to preferred\n"
elif [ "$FIREWALL_MODE" = "normal" ] && [ "$LEGACY_IPTABLES" = "false" ]; then
  printf " * iptables set to preferred\n"
else
  printf " * Updating iptables to preferred\n"
  if [ "$LEGACY_IPTABLES"  = "true" ]; then 
    if [ "$(grep ^NAME= /etc/os-release | cut -d '=' -f 2 | tr -d '"')" = "Alpine Linux" ]; then 
      printf "   * OS Detected as Alpine\n"
      printf "   * Switching to legacy iptables..."
      ln -sf "$IPTABLES_LEGACY_ALPINE" /usr/sbin/iptables
      exitOnError $?
      printf "Done\n"
    else
      printf "   * OS Detected as Ubuntu\n"
      printf "   * Switching to legacy iptables..."
      ln -sf "$IPTABLES_LEGACY" /usr/sbin/iptables
      ln -sf "$IP6TABLES_LEGACY" /usr/sbin/ip6tables
      exitOnError $?
      printf "Done\n"
    fi
  else
    if [ "$(grep ^NAME= /etc/os-release | cut -d '=' -f 2 | tr -d '"')" = "Alpine Linux" ]; then 
      printf "   * OS Detected as Alpine\n"
      printf "   * Switching to normal iptables..."
      ln -sf "$IPTABLES_NFT_ALPINE" /sbin/iptables
      exitOnError $?
      printf "Done\n"
    else
      printf "   * OS Detected as Ubuntu\n"
      printf "   * Switching to normal iptables..."
      ln -sf "$IPTABLES_NFT" /usr/sbin/iptables
      ln -sf "$IP6TABLES_NFT" /usr/sbin/ip6tables
      exitOnError $?
      printf "Done\n"
    fi
  fi
fi
printf "[INFO] Setting firewall\n"
printf " * Blocking everything\n"
printf "   * Deleting all iptables rules..."
OUTPUT=$(iptables --flush 2>&1)
exitOnError $? "$OUTPUT"
OUTPUT=$(iptables --delete-chain 2>&1)
exitOnError $? "$OUTPUT"
OUTPUT=$(iptables -t nat --flush 2>&1)
exitOnError $? "$OUTPUT"
OUTPUT=$(iptables -t nat --delete-chain 2>&1)
exitOnError $? "$OUTPUT"
printf "DONE\n"
printf "   * Block input traffic..."
OUTPUT=$(iptables -P INPUT DROP 2>&1)
exitOnError $? "$OUTPUT"
printf "DONE\n"
printf "   * Block output traffic..."
OUTPUT=$(iptables -F OUTPUT 2>&1)
exitOnError $? "$OUTPUT"
OUTPUT=$(iptables -P OUTPUT DROP 2>&1)
exitOnError $? "$OUTPUT"
printf "DONE\n"
printf "   * Block forward traffic..."
OUTPUT=$(iptables -P FORWARD DROP 2>&1)
exitOnError $? "$OUTPUT"
printf "DONE\n"

printf " * Creating general rules\n"
printf "   * Accept established and related input and output traffic..."
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
exitOnError $?
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
exitOnError $?
printf "DONE\n"
printf "   * Accept local loopback input and output traffic..."
iptables -A OUTPUT -o lo -j ACCEPT
exitOnError $?
iptables -A INPUT -i lo -j ACCEPT
exitOnError $?
printf "DONE\n"

# Set the default WebUI interface
if [ -z $WEBUI_INTERFACES ]; then
  WEBUI_INTERFACES=$INTERFACE
fi

printf " * Creating rules for webui-port:$WEBUI_PORT\n"
# Loop through each WebUI interface
for webui_interface in  $(echo $WEBUI_INTERFACES | sed "s/,/ /g"); do
  # Apply OUTPUT rules (allow outgoing traffic on WEBUI_PORT)
  printf "   * * Applied iptables rules for webui on interface: $webui_interface..."
  iptables -A OUTPUT -o "$webui_interface" -p tcp --dport "$WEBUI_PORT" -j ACCEPT
  iptables -A OUTPUT -o "$webui_interface" -p tcp --sport "$WEBUI_PORT" -j ACCEPT
  # Apply INPUT rules (allow incoming traffic on WEBUI_PORT)
  iptables -A INPUT -i "$webui_interface" -p tcp --dport "$WEBUI_PORT" -j ACCEPT
  iptables -A INPUT -i "$webui_interface" -p tcp --sport "$WEBUI_PORT" -j ACCEPT
  printf "DONE\n"
done

printf " * Creating VPN routes..."
ip rule add from $(ip route get 1 | ack -o '(?<=src )(\S+)') table 128
#if [ "$VPN_CLIENT" = "wireguard" ]; then
#fi
ip route add table 128 to $(ip route get 1 | ack -o '(?<=src )(\S+)')/32 dev $(ip -4 route ls | ack default | ack -o '(?<=dev )(\S+)')
ip route add table 128 default via $(ip -4 route ls | ack default | ack -o '(?<=via )(\S+)')
printf "DONE\n"

printf " * Creating VPN rules\n"
for ip in $VPNIPS; do
  printf "   * * Accept output traffic to VPN server $ip through $INTERFACE, port udp $PORT..."
  iptables -A OUTPUT -d $ip -o $INTERFACE -p udp -m udp --dport $PORT -j ACCEPT
  exitOnError $?
  printf "DONE\n"
done

printf "   * Accept all output traffic through $VPN_DEVICE..."
iptables -A OUTPUT -o $VPN_DEVICE -j ACCEPT
exitOnError $?
printf "DONE\n"

if [ "$ALLOW_LOCAL_SUBNET_TRAFFIC" = "true" ]; then
  printf " * Creating local subnet rules\n"
  printf "   * Accept input and output traffic to and from $SUBNET..."
  iptables -A INPUT -s $SUBNET -d $SUBNET -j ACCEPT
  iptables -A OUTPUT -s $SUBNET -d $SUBNET -j ACCEPT
  printf "DONE\n"
fi

for EXTRASUBNET in $(echo $EXTRA_SUBNETS | sed "s/,/ /g")
do
  printf "   * Accept input traffic through $INTERFACE from $EXTRASUBNET to $SUBNET..."
  iptables -A INPUT -i $INTERFACE -s $EXTRASUBNET -d $SUBNET -j ACCEPT
  exitOnError $?
  printf "DONE\n"
  # iptables -A OUTPUT -d $EXTRASUBNET -j ACCEPT
  # iptables -A OUTPUT -o $INTERFACE -s $SUBNET -d $EXTRASUBNET -j ACCEPT
done

############################################
# VPN LAUNCH
############################################
printf "[INFO] Connecting to VPN\n"

printf " * Rotating logs\n"
mkdir -p "$VPN_LOG_DIR"
# Rotate logs
i=0
while [ $i -lt $VPN_MAX_ITERATIONS ]; do
    if [ -f "$VPN_LOG_DIR/*.log.$i" ]; then
        mv "$VPN_LOG_DIR/*.log.$i" "$VPN_LOG_DIR/*.log.$((i+1))"
    fi
    i=$((i + 1))
done

# Move the current log file to the first iteration
if [ -f "$VPN_LOG_DIR/*.log" ]; then
    mv "$VPN_LOG_DIR/*.log" "$VPN_LOG_DIR/*.log.1"
fi
cd "$TARGET_PATH"

if [ "$VPN_CLIENT" = "wireguard" ]; then
  printf " * Bringing up Wireguard\n"
  doas -u root wg-quick up pia >> "$VPN_LOG_DIR/wireguard.log" 2>&1
  ip route add 0.0.0.0/1 dev pia
  ip route add 128.0.0.0/1 dev pia

else
  printf " * Opening OpenVPN\n"
  openvpn --config config.ovpn --daemon --log "$VPN_LOG_DIR/openvpn.log" "$@"
fi

############################################
# qBittorrent config
############################################
printf "[INFO] Checking qBittorrent config\n"
if [ ! -e /config/qBittorrent/config/qBittorrent.conf ]; then
	mkdir -p /config/qBittorrent/config && cp /app/qBittorrent.conf /config/qBittorrent/config/qBittorrent.conf
	chmod 755 /config/qBittorrent/config/qBittorrent.conf
	printf " * Copying default qBittorrent config\n"
fi

# Updating config with user prefrences 
if [ "${HOSTHEADERVALIDATION}" = "true" ] || [ "${HOSTHEADERVALIDATION}" = "false" ]; then
  printf " * Updateing HostHeaderValidation to $HOSTHEADERVALIDATION\n"
  sed -i "s/WebUI\\\HostHeaderValidation=\(true\|false\)/WebUI\\\HostHeaderValidation=$HOSTHEADERVALIDATION/g" /config/qBittorrent/config/qBittorrent.conf
fi

if [ "${CSRFPROTECTION}" = "true" ] || [ "${CSRFPROTECTION}" = "false" ]; then
  printf " * Updateing CSRFProtection to $CSRFPROTECTION\n"
  sed -i "s/WebUI\\\CSRFProtection=\(true\|false\)/WebUI\\\CSRFProtection=$CSRFPROTECTION/g" /config/qBittorrent/config/qBittorrent.conf
fi

# Set user and group id
if [ -n "$UID" ]; then
    sed -i "s|^qbtUser:x:[0-9]*:|qbtUser:x:$UID:|g" /etc/passwd
fi

if [ -n "$GID" ]; then
    sed -i "s|^\(qbtUser:x:[0-9]*\):[0-9]*:|\1:$GID:|g" /etc/passwd
    sed -i "s|^qbtUser:x:[0-9]*:|qbtUser:x:$GID:|g" /etc/group
fi

# Set ownership of folders, but don't set ownership of existing files in downloads
chown qbtUser:qbtUser /downloads
chown qbtUser:qbtUser -R /config

# Set permissions of folders, but don't set permissions of existing files in downloads
chmod 755 /downloads
chmod 700 -R /config

# Wait until vpn is up
printf "[INFO] Waiting for VPN to connect"
looping=1
while : ; do
	tunnelstat=$(ifconfig | ack "tun|tap|pia")
	if [ ! -z "${tunnelstat}" ]; then
		break
	else
    # Search for lines containing 'ERROR:'
    if [ "$VPN_CLIENT" = "wireguard" ]; then
      ERROR_LINES=$(grep "ERROR:" "$VPN_LOG_DIR/wireguard.log")
      AUTH_ERROR_LINES=""
    else
      ERROR_LINES=$(grep "ERROR:" "$VPN_LOG_DIR/openvpn.log")
      AUTH_ERROR_LINES=$(grep "AUTH_FAILED" "$VPN_LOG_DIR/openvpn.log")
    fi

    if [ -n "$ERROR_LINES" ] && [ "$VPN_CLIENT" = "openvpn" ]; then
      # If errors are found, print the openvpn log
      printf "\n"
      printf "[ERROR] OpenVPN has encounted an error, see log below and check\n"
      printf "https://github.com/j4ym0/pia-qbittorrent-docker/wiki/Waiting-for-VPN-and-OpenVPN-Fatal-Error \n"
      printf "---------------------------------------\n"
      printf "$(cat "$VPN_LOG_DIR/openvpn.log")\n"
      ERROR_LINES=$(grep "fatal error" "$VPN_LOG_DIR/openvpn.log")
      if [ -n "$ERROR_LINES" ]; then
        exit 6
      fi
      sleep 30
    elif [ -n "$AUTH_ERROR_LINES" ] && [ "$VPN_CLIENT" = "openvpn" ]; then
        printf "\n"
        printf "[ERROR] VPN Authentication Failed. Check your PIA username and password"
        exit 7
    else
      if [ "$looping" -gt 120 ]; then
        # Been waiting 2 mins, someting mins be wrong
        printf "\n"
        printf "[ERROR] Unable to connect to VPN. Check your network connection, PIA username and password"
        exit 7
      else
        # If no errors found, waiting a bit longer
        printf "."
        sleep 1
      fi
    fi
	fi
  looping=$((looping + 1))
done
printf "\n"

############################################
# Port Forwarding
############################################
PF_GATEWAY=""
PF_CERT=""
PF_CONNECT=""
if is_enabled "$PORT_FORWARDING"; then
  printf "[INFO] Setting up port forwarding\n"

  # Setup the port forwading parameters depending on the VPN client
  if [ "$VPN_CLIENT" = "wireguard" ]; then
    printf " * Using Wireguard port forwarding\n"
    PF_GATEWAY=$wg_cn
    PF_CERT="--cacert /app/ca.rsa.4096.crt"
    PF_CONNECT="--connect-to $wg_cn::$wg_ip:"
  else
    printf " * Using OpenVPN port forwarding\n"
    PF_GATEWAY=$(route -n | grep -e 'UG.*tun0' | awk '{print $2}' | awk 'NR==1{print $1}')
    PF_CERT="-k"
  fi

  # Get a token from PIA to authenticate the port forwarding request
  # --location just to follow redirects
  piaToken=$(curl -s --location --request POST \
            'https://www.privateinternetaccess.com/api/client/v2/token' \
            --form "username=$(sed '1!d' /auth.conf)" \
            --form "password=$(sed '2!d' /auth.conf)" | jq -r '.token')
  if [ ! -z "$piaToken" ]; then
    printf " * Got PIA token\n"
  fi

  # Get the signature and payload for port forwarding
  pia_sig=$(curl --get -s \
            $PF_CONNECT \
            $PF_CERT \
            --data-urlencode "token=$piaToken" \
            "https://$PF_GATEWAY:19999/getSignature")


  if [ -z "$pia_sig" ]; then
    printf "[ERROR] Unable to start port forwarding. Is port forwarding avalable in your chosen region?\n"
    printf "https://github.com/j4ym0/pia-qbittorrent-docker/wiki/PIA-Servers \n"
    exit 4
  elif [ "$(echo "$pia_sig" | jq -r '.status')" = "ERROR" ]; then
    printf "[ERROR] Unable to start port forwarding\n"
    printf "$(echo "$pia_sig" | jq -r '.message') \n"
    exit 4
  fi

  signature=$(echo "$pia_sig" | jq -r '.signature')
  if [ ! -z "$signature" ]; then
    printf " * Got signature\n"
  fi

  payload=$(echo "$pia_sig" | jq -r '.payload')
  payloadDecoded=$(echo "$payload" | base64 -d | jq)
  if [ ! -z "$payloadDecoded" ]; then
    printf " * Decoded payload\n"
  fi

  PF_PORT=$(echo "$payloadDecoded" | jq -r '.port')
  if [ ! -z "$PF_PORT" ]; then
    printf " * Your Forwarding port is $PF_PORT\n"
  fi

  # Request port forwarding
  binding=$(curl -sGk \
            $PF_CONNECT \
            $PF_CERT \
            --data-urlencode "payload=$payload" \
            --data-urlencode "signature=$signature" \
            https://$PF_GATEWAY:19999/bindPort)

  printf " * $(echo $binding | jq -r '.message')\n"

  if [ "$(echo "$binding" | jq -r '.status')" = "OK" ]; then
    # Port will be added so we will open the port ont the firewall
    printf " * Adding port to firewall on interfce $VPN_DEVICE\n"
    iptables -A INPUT -i $VPN_DEVICE -p tcp --dport $PF_PORT -j ACCEPT
    exitOnError $?
  else
    printf "[ERROR] $(echo $binding)\n"
    exit 4
  fi

  # Add port the qBittorrent config
  printf " * Updating port in qBittorrent config\n"
  sed -i "s/Session\\\Port=[0-9]*/Session\\\Port=$PF_PORT/g" /config/qBittorrent/config/qBittorrent.conf
fi

############################################
# Run post-vpn-connect hook script
############################################

if [ -f /config/post-vpn-connect.sh ]; then
  printf "[INFO] Running post-vpn-connect.sh\n"
  . /config/post-vpn-connect.sh
fi

############################################
# Start qBittorrent
############################################

# add CTRL+C to exit loop from command line when qBittorrent has been launched
trap 'echo "CTRL+C Detected. Exiting" && exit 1' INT

printf "[INFO] Launching qBittorrent\n"
exec doas -u qbtUser qbittorrent-nox --webui-port=$WEBUI_PORT --profile=/config &

i=1
while : ; do
	sleep 1
  if [ $i -gt 600 ]; then
    i=1
    if is_enabled "$PORT_FORWARDING"; then
      binding=$(curl -sGk \
            $PF_CONNECT \
            $PF_CERT \
            --data-urlencode "payload=$payload" \
            --data-urlencode "signature=$signature" \
            https://$PF_GATEWAY:19999/bindPort)

#      now just for debugging
#      printf "Port Forwarding - $(echo $binding | jq -r '.message')\n"

      if [ "$(echo "$binding" | jq -r '.status')" != "OK" ]; then
        printf "[ERROR] Port forwarding failed\n"
        exit 5
      fi
    fi
  fi
  if ! `pgrep -x "qbittorrent-nox" > /dev/null` 
  then
    break
  fi
  i=$((i + 1))
done
