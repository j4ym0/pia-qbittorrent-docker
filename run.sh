#! /bin/sh

server="south africa"

USER="p7492354"
PASSWORD="CP1038sf0vh@"
VPNIPS='195.78.54.171'
DNS_SERVERS="209.222.18.222,209.222.18.218"

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
  '.regions[] | select(.name==$REGION),select(.id==$REGION_ID)' /git/data.json ) ; then
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
  --cacert "/git/ca.rsa.4096.crt" \
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
