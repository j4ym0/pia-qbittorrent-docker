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

# Define paths for iptables versions
IPTABLES_LEGACY="/usr/sbin/iptables-legacy"
IP6TABLES_LEGACY="/usr/sbin/ip6tables-legacy"
IPTABLES_NFT="/usr/sbin/iptables-nft"
IP6TABLES_NFT="/usr/sbin/ip6tables-nft"
IPTABLES_LEGACY_ALPINE="/sbin/xtables-legacy-multi"
IPTABLES_NFT_ALPINE="/sbin/xtables-nft-multi"

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
printf " Iptables version: $(iptables --version | cut -d" " -f2)\n"
printf " qBittorrent version: $(qbittorrent-nox --version | cut -d" " -f2)\n"
printf " =========================================\n"

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
if [ -z $OPENVPN_LOG_DIR ]; then
  OPENVPN_LOG_DIR=/logs
fi
if [ -z $OPENVPN_MAX_ITERATIONS ]; then
  OPENVPN_MAX_ITERATIONS=3
fi

############################################
# SHOW PARAMETERS
############################################
printf "\n"
printf "System parameters:\n"
printf " * userID: $UID\n"
printf " * groupID: $GID\n"
printf " * timezone: $(date +"%Z %z")\n"
printf "OpenVPN parameters:\n"
printf " * Region: $server\n"
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
# Best option is to mount a secure file using docker
# -v /auth-file.conf:/auth.config
#####################################################
if [ -f /auth.conf ]; then
  if [ "$(wc -l < /auth.conf)" -gt 0 ] && [ "$(wc -c < /auth.conf)" -gt 10 ]; then
    printf "[INFO] /auth.conf file looks good\n"
  else
    printf "[INFO] Please check /auth.conf file. Check line 1 is your username and line 2 is your password\n"
    exit 7
  fi
else
  # No auth file mounted creating it from environment variables
  printf "[INFO] Unable to find /auth.conf file, creating it from environment variables\n"
  exitIfUnset USER
  exitIfUnset PASSWORD
  printf "[INFO] Writing USER and PASSWORD to protected file /auth.conf..."
  echo "$USER" > /auth.conf
  exitOnError $?
  echo "$PASSWORD" >> /auth.conf
  exitOnError $?
  chmod 400 /auth.conf
  exitOnError $?
  printf "DONE\n"
fi
# Check if user vars have been set and clear them
if [ -n "$USER" ] || [ -n "$PASSWORD" ]; then
  printf "[INFO] Clearing environment variables USER and PASSWORD..."
  unset -v USER
  unset -v PASSWORD
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
printf "[INFO] Reading OpenVPN configuration...\n"
CONNECTIONSTRING=$(ack 'privacy.network' "/openvpn/nextgen/$server.ovpn")
exitOnError $?
PORT=$(echo $CONNECTIONSTRING | cut -d' ' -f3)
if [ "$PORT" = "" ]; then
  printf "[ERROR] Port not found in /openvpn/nextgen/$server.ovpn\n"
  exit 1
fi
PIADOMAIN=$(echo $CONNECTIONSTRING | cut -d' ' -f2)
if [ "$PIADOMAIN" = "" ]; then
  printf "[ERROR] Domain not found in /openvpn/nextgen/$server.ovpn\n"
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
# Remove the CRL from the ovpn file as it is not compatable with openssl 3
sed -i '/<crl-verify>/,/<\/crl-verify>/d'  "$TARGET_PATH/config.ovpn"
exitOnError $? "Cannot remove crl-verify from $TARGET_PATH/config.ovpn"
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
VPN_DEVICE=$(cat $TARGET_PATH/config.ovpn | ack 'dev ' | cut -d" " -f 2)0
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
  printf " * iptables set to prefered\n"
elif [ "$FIREWALL_MODE" = "normal" ] && [ "$LEGACY_IPTABLES" = "false" ]; then
  printf " * iptables set to prefered\n"
else
  printf " * Updateing iptables to prefered\n"
  if [ "$LEGACY_IPTABLES"  = "true" ]; then 
    if [ "$(grep ^NAME= /etc/os-release | cut -d '=' -f 2 | tr -d '"')" = "Alpine Linux" ]; then 
      printf "   * OS Detected as Alpine\n"
      printf "   * Switching to legacy iptables..."
      ln -sf "$IPTABLES_LEGACY_ALPINE" /sbin/iptables
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

printf " * Rotating logs\n"
mkdir -p "$OPENVPN_LOG_DIR"
# Rotate logs
i=0
while [ $i -lt $OPENVPN_MAX_ITERATIONS ]; do
    if [ -f "$OPENVPN_LOG_DIR/openvpn.log.$i" ]; then
        mv "$OPENVPN_LOG_DIR/openvpn.log.$i" "$OPENVPN_LOG_DIR/openvpn.log.$((i+1))"
    fi
    i=$((i + 1))
done

# Move the current log file to the first iteration
if [ -f "$OPENVPN_LOG_DIR/openvpn.log" ]; then
    mv "$OPENVPN_LOG_DIR/openvpn.log" "$OPENVPN_LOG_DIR/openvpn.log.1"
fi

cd "$TARGET_PATH"
openvpn --config config.ovpn --daemon --log "$OPENVPN_LOG_DIR/openvpn.log" "$@"

############################################
# qBittorrent config
############################################
printf "[INFO] Checking qBittorrent config\n"
if [ ! -e /config/qBittorrent/config/qBittorrent.conf ]; then
	mkdir -p /config/qBittorrent/config && cp /qBittorrent.conf /config/qBittorrent/config/qBittorrent.conf
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

# Wait until vpn is up
printf "[INFO] Waiting for VPN to connect"
looping=1
while : ; do
	tunnelstat=$(ifconfig | ack "tun|tap")
	if [ ! -z "${tunnelstat}" ]; then
		break
	else
    # Search for lines containing 'ERROR:'
    ERROR_LINES=$(grep "ERROR:" "$OPENVPN_LOG_DIR/openvpn.log")
    AUTH_ERROR_LINES=$(grep "AUTH_FAILED" "$OPENVPN_LOG_DIR/openvpn.log")
    if [ -n "$ERROR_LINES" ]; then
      # If errors are found, print the openvpn log
      printf "\n"
      printf "[ERROR] OpenVPN has encounted an error, see log below and check\n"
      printf "https://github.com/j4ym0/pia-qbittorrent-docker/wiki/Waiting-for-VPN-and-OpenVPN-Fatal-Error \n"
      printf "---------------------------------------\n"
      printf "$(cat "$OPENVPN_LOG_DIR/openvpn.log")\n"
      ERROR_LINES=$(grep "fatal error" "$OPENVPN_LOG_DIR/openvpn.log")
      if [ -n "$ERROR_LINES" ]; then
        exit 6
      fi
      sleep 30
    elif [ -n "$AUTH_ERROR_LINES" ]; then
        printf "\n"
        printf "[ERROR] VPN Authentication Failed. Check your username and password"
        exit 7
    else
      if [ "$looping" -gt 120 ]; then
        # Been waiting 2 mins, someting mins be wrong
        printf "\n"
        printf "[ERROR] Unable to connect to VPN. Check your network connection, username and password"
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
if "$PORT_FORWARDING"; then
  printf "[INFO] Setting up port forwarding\n"
  pia_gen=$(curl -s --location --request POST \
  'https://www.privateinternetaccess.com/api/client/v2/token' \
  --form "username=$(sed '1!d' /auth.conf)" \
  --form "password=$(sed '2!d' /auth.conf)" )
  
  piatoken=$(echo "$pia_gen" | jq -r '.token')
  if [ ! -z "$piatoken" ]; then
    printf " * Got PIA token\n"
  fi

  PIA_GATEWAY=$(route -n | grep -e 'UG.*tun0' | awk '{print $2}' | awk 'NR==1{print $1}' )
  if [ ! -z "$PIA_GATEWAY" ]; then
    printf " * Got PIA gateway $PIA_GATEWAY\n"
  fi

  piasif=$(curl -k -s "$(sed '1!d' /auth.conf):$(sed '2!d' /auth.conf))" "https://$PIA_GATEWAY:19999/getSignature?token=$piatoken")
  if [ ! -z "$piasif" ]; then
    printf " * Getting PIA Signature\n"
  else
    printf "[ERROR] Unable to start port forwarding. Is port forwarding avalable in your chosen region?\n"
    printf "https://github.com/j4ym0/pia-qbittorrent-docker/wiki/PIA-Servers \n"
    exit 4
  fi

  signature=$(echo "$piasif" | jq -r '.signature')
  if [ ! -z "$signature" ]; then
    printf " * Got signature\n"
  fi

  payload_ue=$(echo "$piasif" | jq -r '.payload')
  payload=$(echo "$payload_ue" | base64 -d | jq)
  if [ ! -z "$payload" ]; then
    printf " * Decoded payload\n"
  fi

  PF_PORT=$(echo "$payload" | jq -r '.port')
  if [ ! -z "$PF_PORT" ]; then
    printf " * Your Forwarding port is $PF_PORT\n"
  fi

  binding=$(curl -sGk --data-urlencode "payload=$payload_ue" --data-urlencode "signature=$signature" https://$PIA_GATEWAY:19999/bindPort)
  if [ `echo "$binding" | jq -r '.status'` = "OK" ]; then
    printf " * $(echo $binding | jq -r '.message')\n"
    # Port will be added so we will open the port ont the firewall
    printf " * adding port to firewall\n"
    iptables -A INPUT -i tun0 -p tcp --dport $PF_PORT -j ACCEPT
    exitOnError $?
  else
    printf " * $(echo $binding | jq -r '.message')\n"
    exit 4
  fi
fi

if "$PORT_FORWARDING"; then
  sed -i "s/Session\\\Port=[0-9]*/Session\\\Port=$PF_PORT/g" /config/qBittorrent/config/qBittorrent.conf
fi

if [ -n "$UMASK" ]; then
    umask "$UMASK"
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
    if "$PORT_FORWARDING"; then
      binding=$(curl -sGk --data-urlencode "payload=$payload_ue" --data-urlencode "signature=$signature" https://$PIA_GATEWAY:19999/bindPort)
      if [ `echo "$binding" | jq -r '.status'` = "OK" ]; then
        printf "Port Forwarding - $(echo $binding | jq -r '.message')\n"
      else
        printf "Port Forwarding - $(echo $binding | jq -r '.message')\n"
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
