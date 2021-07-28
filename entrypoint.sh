#!/bin/sh

exitOnError(){
  # $1 must be set to $?
  status=$1
  message=$2
  [ "$message" != "" ] || message="Undefined error"
  if [ $status != 0 ]; then
    printf "[ERROR] $message, with status $status\n"
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

# link the lib for qbittorrent for alpine
export LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64:${LD_LIBRARY_PATH}

# convert vpn to lower case for dir
server=$(echo "$REGION" | tr '[:upper:]' '[:lower:]')

printf " =========================================\n"
printf " ============== qBittorrent ==============\n"
printf " =================== + ===================\n"
printf " ============= PIA CONTAINER =============\n"
printf " =========================================\n"
printf " OS: $(cat /etc/os-release | ack PRETTY_NAME=\"*\" | cut -d "\"" -f 2 | cut -d "\"" -f 1)\n"
printf " =========================================\n"
printf " OpenVPN version: $(openvpn --version | head -n 1 | ack "OpenVPN [0-9\.]* " | cut -d" " -f2)\n"
printf " Wireguard version: $(wg --version | head -n 1 | ack " v[0-9\.]* " | cut -d" " -f2)\n"
printf " Iptables version: $(iptables --version | cut -d" " -f2)\n"
printf " qBittorrent version: $(qbittorrent-nox --version | cut -d" " -f2)\n"
printf " =========================================\n"


############################################
# CHECK if client should be openvpn or wireguard
############################################
if [ -z $CLIENT ]; then
  printf "Defaulting to OpenVPN\n"
  CLIENT="openvpn"
fi

############################################
# CHECK PARAMETERS
############################################
exitIfUnset USER
exitIfUnset PASSWORD
if [ ! -e "/openvpn/nextgen/$server.ovpn" ]; then
  printf " =========================================\n"
  printf " =========Server is not Valid=============\n"
  printf " =========================================\n"
  exit 2
fi
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

############################################
# SHOW PARAMETERS
############################################
printf "\n"
printf "VPN parameters:\n"
printf " * Region: $server\n"
printf " * Client: $CLIENT\n"
printf "Local network parameters:\n"
printf " * Web UI port: $WEBUI_PORT\n"
printf " * Adding PIA DNS Servers\n"
cat /dev/null > /etc/resolv.conf
for name_server in $(echo $DNS_SERVERS | sed "s/,/ /g")
do
	echo " * * Adding $name_server to resolv.conf"
	echo "nameserver $name_server" >> /etc/resolv.conf
done


#####################################################
# Writes to protected file and remove USER, PASSWORD
#####################################################
if [ -f /auth.conf ]; then
  printf "[INFO] /auth.conf already exists\n"
else
  printf "[INFO] Writing USER and PASSWORD to protected file /auth.conf..."
  echo "$USER" > /auth.conf
  exitOnError $?
  echo "$PASSWORD" >> /auth.conf
  exitOnError $?
  chmod 400 /auth.conf
  exitOnError $?
  printf "DONE\n"
  printf "[INFO] Clearing environment variables USER and PASSWORD..."
  printf "DONE\n"
fi

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
IP=$(ifconfig)
printf "$ip"
printf "[INFO] Reading OpenVPN configuration...\n"
CONNECTIONSTRING=$(ack 'privacy.network' "/openvpn/nextgen/$server.ovpn")
exitOnError $?
PORT=$(echo $CONNECTIONSTRING | cut -d' ' -f3)
if [ "$PORT" = "" ]; then
  printf "[ERROR] Port not found in for $server\n"
  exit 1
fi
PIADOMAIN=$(echo $CONNECTIONSTRING | cut -d' ' -f2)
if [ "$PIADOMAIN" = "" ]; then
  printf "[ERROR] Domain not found for $server\n"
  exit 1
fi
printf " * Port: $PORT\n"
printf " * Domain: $PIADOMAIN\n"
printf "[INFO] Detecting IP addresses corresponding to $PIADOMAIN...\n"
VPNIPS=$(dig $PIADOMAIN +short | grep '^[.0-9]*$')
exitOnError $?
if [ "$VPNIPS" = "" ]; then
  printf " Unable to connect to $PIADOMAIN"
  exit 3
fi
for ip in $VPNIPS; do
  printf "   $ip\n";
done



if [ $CLIENT == "wireguard" ]; then
  pia_gen=$(curl -s -u "$USER:$PASSWORD" \
    "https://privateinternetaccess.com/gtoken/generateToken")

  if [ "$(echo "$pia_gen" | jq -r '.status')" != "OK" ]; then
    printf " ERROR: getting token\n"
    printf " =========================================\n"
    printf " =======Check username and pssword========\n"
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

  if regiondata=$( jq --arg REGION_ID "$(echo "$server" | awk '{print tolower($0)}')" \
    --arg REGION "$(echo $server | awk '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) substr($i,2) }}1')" -er \
    '.regions[] | select(.name==$REGION),select(.id==$REGION_ID)' /app/data.json ) ; then
    printf " * Got PIA regon data\n"
  else
    printf "ERROR Getting region data, check you setting"
    exit 4
  fi

  WG_IP="$(echo $regiondata | jq -r '.servers.wg[0].ip')"
  WG_HOSTNAME="$(echo $regiondata | jq -r '.servers.wg[0].cn')"

  printf " * Getting wireguard config for $server...\n"
  wireguard_json="$(curl -s -G \
    --connect-to "$WG_HOSTNAME::$WG_IP:" \
    --cacert "/app/ca.rsa.4096.crt" \
    --data-urlencode "pt=${piatoken}" \
    --data-urlencode "pubkey=$publicKey" \
    "https://${WG_HOSTNAME}:1337/addKey" )"

  if [ "$(echo "$wireguard_json" | jq -r '.status')" != "OK" ]; then
    printf "ERROR Getting wireguard Settings - $(echo "$wireguard_json" | jq -r '.status')"
    exit 5
  fi

  printf "Writing Wireguard settings /etc/wireguard/pia.conf\n"
  mkdir -p /etc/wireguard
  echo "
  [Interface]
  Address = $(echo "$wireguard_json" | jq -r '.peer_ip')
  PrivateKey = $privateKey" > /etc/wireguard/pia.conf
  echo "DNS = $(echo "$wireguard_json" | jq -r '.dns_servers[0]')" >> /etc/wireguard/pia.conf
  echo "[Peer]
  PersistentKeepalive = 25
  PublicKey = $(echo "$wireguard_json" | jq -r '.server_key')
  AllowedIPs = 0.0.0.0/0
  Endpoint = ${WG_IP}:$(echo "$wireguard_json" | jq -r '.server_port')
  " >> /etc/wireguard/pia.conf

  printf "Bringing up wireguard\n"
  wg-quick up pia || exit 1
else
  ############################################
  #         n OpenVPN configuration
  ############################################
  ############################################
  # Writing target OpenVPN files
  ############################################
  TARGET_PATH="/openvpn/target"
  printf "[INFO] Creating target OpenVPN files in $TARGET_PATH..."
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
if [ CLIENT == "wireguard" ]; then
  VPN_DEVICE="pia"
else
  VPN_DEVICE=$(cat $TARGET_PATH/config.ovpn | ack 'dev ' | cut -d" " -f 2)0
fi
exitOnError $?
printf "$VPN_DEVICE\n"


############################################
# FIREWALL
############################################
printf "[INFO] Setting firewall\n"
printf " * Blocking everyting\n"
printf "   * Deleting all iptables rules..."
iptables --flush
exitOnError $?
iptables --delete-chain
exitOnError $?
iptables -t nat --flush
exitOnError $?
iptables -t nat --delete-chain
exitOnError $?
printf "DONE\n"
printf "   * Block input traffic..."
iptables -P INPUT DROP
exitOnError $?
printf "DONE\n"
printf "   * Block output traffic..."
iptables -F OUTPUT
exitOnError $?
iptables -P OUTPUT DROP
exitOnError $?
printf "DONE\n"
printf "   * Block forward traffic..."
iptables -P FORWARD DROP
exitOnError $?
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

printf "   * Accept traffic to webui-port:$WEBUI_PORT..."
iptables -A OUTPUT -o eth0 -p tcp --dport $WEBUI_PORT -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport $WEBUI_PORT -j ACCEPT
iptables -A INPUT -i eth0 -p tcp --dport $WEBUI_PORT -j ACCEPT
iptables -A INPUT -i eth0 -p tcp --sport $WEBUI_PORT -j ACCEPT
ip rule add from $(ip route get 1 | ack -o '(?<=src )(\S+)') table 128
ip route add table 128 to $(ip route get 1 | ack -o '(?<=src )(\S+)')/32 dev $(ip -4 route ls | ack default | ack -o '(?<=dev )(\S+)')
ip route add table 128 default via $(ip -4 route ls | ack default | ack -o '(?<=via )(\S+)')
printf "DONE\n"

printf " * Creating VPN rules\n"
for ip in $VPNIPS; do
  printf "   * Accept output traffic to VPN server $ip through $INTERFACE, port udp $PORT..."
  iptables -A OUTPUT -d $ip -o $INTERFACE -p udp -m udp --dport $PORT -j ACCEPT
  exitOnError $?
  printf "DONE\n"
done
printf "   * Accept all output traffic through $VPN_DEVICE..."
iptables -A OUTPUT -o $VPN_DEVICE -j ACCEPT
exitOnError $?
printf "DONE\n"

printf " * Creating local subnet rules\n"
printf "   * Accept input and output traffic to and from $SUBNET..."
iptables -A INPUT -s $SUBNET -d $SUBNET -j ACCEPT
iptables -A OUTPUT -s $SUBNET -d $SUBNET -j ACCEPT
printf "DONE\n"
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
# OPENVPN LAUNCH
############################################
printf "[INFO] Launching OpenVPN\n"
cd "$TARGET_PATH"
openvpn --config config.ovpn --daemon "$@"

############################################
# Start qBittorrent
############################################
printf "[INFO] Checking qBittorrent config\n"
if [ ! -e /config/qBittorrent/config/qBittorrent.conf ]; then
	mkdir -p /config/qBittorrent/config && cp /app/qBittorrent.conf /config/qBittorrent/config/qBittorrent.conf
	chmod 755 /config/qBittorrent/config/qBittorrent.conf
	printf " * copying default qBittorrent config\n"
fi

# Wait until vpn is up
printf "[INFO] Waiting for VPN to connect\n"
while : ; do
	tunnelstat=$(ifconfig | ack "tun|tap")
	if [ ! -z "${tunnelstat}" ]; then
		break
	else
		sleep 1
	fi
done

printf "[INFO] Launching qBittorrent\n"
qbittorrent-nox --webui-port=$WEBUI_PORT -d --profile=/config
status=$?
printf "\n =========================================\n"

while : ; do
  proc=$(pgrep qbittorrent-nox)
  if [ -z "${proc}" ]; then
    exit
  fi
	sleep 10s
done
