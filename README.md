# Private Internet Access Client (qBittorrent+OpenVPN+Iptables+DNS on alpine/ubuntu)
# Nextgen (GEN4) Server compatible

<p align="center">
  <a href="https://github.com/j4ym0/pia-qbittorrent-docker/releases">
    <img alt="latest version" src="https://img.shields.io/github/v/tag/j4ym0/pia-qbittorrent-docker.svg?style=flat-square" />
  </a>
  <a href="https://hub.docker.com/r/j4ym0/pia-qbittorrent">
    <img alt="Pulls from DockerHub" src="https://img.shields.io/docker/pulls/j4ym0/pia-qbittorrent.svg?style=flat-square" />
  </a>
</p>

*Lightweight qBittorrent & Private Internet Access VPN client*

[![PIA Docker OpenVPN](https://github.com/j4ym0/pia-qbittorrent-docker/raw/master/readme/title.png)](https://hub.docker.com/r/j4ym0/pia-qbittorrent/)



<details><summary>Click to show base components</summary><p>

- [Ubuntu 24.04](https://ubuntu.com) for a base image
- [Alpine 3.20.0](https://alpinelinux.org) for a base image
- [OpenVPN 2.6.11] Alpine OpenVPN (https://pkgs.alpinelinux.org/package/v3.20/main/x86_64/openvpn) to tunnel to PIA nextgen servers
- [OpenVPN 2.6.9] Ubuntu OpenVPN (https://packages.ubuntu.com/bionic/openvpn) to tunnel to PIA nextgen servers
- [IPtables 1.8.10](https://packages.ubuntu.com/noble/iptables) enforces the container to communicate only through the VPN or with other containers in its virtual network (acts as a killswitch)

</p></details>

## Features

- <details><summary>Configure everything with environment variables</summary><p>

    - [Destination region](https://www.privateinternetaccess.com/pages/network)
    - Internet protocol
    - Level of encryption
    - PIA Username and password
    - DNS Servers

    </p></details>  
- Self contained qBittorrent
- Exposed webUI
- Downloads & config Volumes
- The *iptables* firewall allows traffic only with needed PIA servers (IP addresses, port, protocol) combinations
- OpenVPN reconnects automatically on failure
- Port forwarding for seeding


## Setup

1. Requirements

    - A Private Internet Access **username** and **password** - [Sign up referral link](http://www.privateinternetaccess.com/pages/buy-a-vpn/1218buyavpn?invite=U2FsdGVkX1-Ki-3bKiIknvTQB1F-2Tz79e8QkNeh5Zc%2CbPOXkZjc102Clh5ih5-Pa_TYyTU)
    - Advanced firewall requirements, if you have one
        - Allow outbound UDP 53 to 84.200.69.80 and 84.200.70.40 this allows the resolve of PIA domain names on startup. 
          - If you set your own `DNS_SERVERS` with the environment variable, allow the outbound connection to your chosen DNS servers IP and Port instead
        - For VPN connection allow outbound UDP 1198, all traffic including DNS should go through the VPN connection once connected.
        - For the built-in web HTTP proxy, allow inbound TCP 8888
    - Docker API 1.25 to support `init`

    </p></details>

1. Launch the container with:  

    Basic Launch
    ```bash
    docker run -d --init --name=pia --restart unless-stopped --cap-add=NET_ADMIN
    -v /My/Downloads/Folder/:/downloads \
    -p 8888:8888 -e REGION="Netherlands" -e USER=xxxxxxx -e PASSWORD=xxxxxxxx \
    j4ym0/pia-qbittorrent
    ```  
    Advanced Launch
    ```bash
    docker run -d --init --name=pia --restart unless-stopped --cap-add=NET_ADMIN \
    -v /My/Downloads/Folder/:/downloads -v /qBittorrent/config/:/config \
    -p 8888:8888 -e REGION="Netherlands" -e USER=xxxxxxx -e PASSWORD=xxxxxxxx \
    -e UID=3 -e GID=3 -e TZ=Etc/UTC -e PORT_FORWARDING=true \
    j4ym0/pia-qbittorrent
    ```

    Note that you can:
    - Change the many [environment variables](#environment-variables) available
    - Use `-p 8888:8888/tcp` to access the HTTP web proxy
    - Pass additional arguments to *openvpn* using Docker's command function (commands after the image name)
    - Use a hook script after connecting to the VPN to execute additional code. See [Hooks](#Hooks)

## Testing

Check the PIA IP address matches your expectations

try [WhatisMyIP.net torrent-ip-checker]([http://checkmyip.torrentprivacy.com/](https://www.whatismyip.net/tools/torrent-ip-checker))

## Environment variables

| Environment variable | Default | Description                                                                               |
|----------------------| --- |-----------------------------------------------------------------------------------------------|
| `REGION`             | `Netherlands` | List of [PIA regions](https://www.privateinternetaccess.com/vpn-server). <br> Tip: use a _ in place of spaces e.g. DE Berlin becomes de_berlin   |
| `USER`               | | Your PIA username                                                                                 |
| `PASSWORD`           | | Your PIA password                                                                                 |
| `PORT_FORWARDING`    | `false` | Set to `true` if you want to enable port forwarding from PIA, This helps with uploading   |
| `WEBUI_PORT`         | `8888` | `1024` to `65535` internal port for HTTP proxy                                             |
| `WEBUI_INTERFACES`   | `eth0` | `eth0` or `eth0,eth1` the interface the WebUI can be accessed through, useful if multiple networks are attached to the container |
| `ALLOW_LOCAL_SUBNET_TRAFFIC`| `false` | Set it `true` to allow connections from your local network to the container, WebUI port is still when `false` |
| `LEGACY_IPTABLES`    | `false` | Set to `true` if nft protocol not supported or you want to use iptables_legacy            |
| `DNS_SERVERS`        | `84.200.69.80,84.200.70.40` | DNS servers to use, comma separated [see list](#DNS Servers)          |
| `UID`                | 700 | The UserID                                                                                    |
| `GID`                | 700 | The GroupID                                                                                   |
| `TZ`                 | | The Timezone                                                                                      |
| `HOSTHEADERVALIDATION`| | Set to `false` if having trouble accessing the WebUI with unauthorized                           |
| `CSRFPROTECTION`     | | Set to `false` if having trouble accessing the WebUI with unauthorized                            |

Port forwarding port will be added to qBittorrent settings on startup. A port can last for up to 2 months.  
To get the user id, run `id -u USER`  
To get the group id for a user, run `id -g USER`
Disabling HOSTHEADERVALIDATION and CSRFPROTECTION could cause security issues if the WebUI is exposed to the internet.

## DNS Servers

Quick list of DNS servers and port advice

|   Server   | Description                                                       |    Port     |
|------------|-------------------------------------------------------------------|-------------|
| 84.200.69.80    | [DNS.WATCH](https://dns.watch/)                              | 53 (UDP)    |
| 84.200.70.40    | [DNS.WATCH](https://dns.watch/)                              | 53 (UDP)    |
| 103.196.38.38   | [Handshake DNS](https://www.hdns.io/)                        | 53 (UDP/TCP)|
| 103.196.38.39   | [Handshake DNS](https://www.hdns.io/)                        | 53 (UDP/TCP)|
| 1.1.1.1         | Cloudflare                                                   | 53 (UDP)    |
| 1.0.0.1         | Cloudflare                                                   | 53 (UDP)    |
| 8.8.8.8         | Google                                                       | 53 (UDP)    |
| 8.8.4.4         | Google                                                       | 53 (UDP)    |

Private Internet Access no longer offer a public facing DNS (209.222.18.222 and 209.222.18.218)

Private Internet Access private DNS server 10.0.0.242 (DNS), 10.0.0.243 (DNS+Streaming), 10.0.0.244 (DNS+MACE), 10.0.0.241 (DNS+Streaming+Mace) can only be used once you are connected to Private Internet Access VPN.

To change to Private Internet Access DNS server, this must be done after the VPN is connected. Add a [Hook Script](#Hooks), create a file in `/config` called `post-vpn-connect.sh`. Then Copy the below into the script file. This script will change the DNS servers after the VPN is connected. The Default DNS (84.200.69.80 or 84.200.70.40) will still be used to resolve the VPN server. 
```bash
# Update the resolv with the PIA DNS server
echo " * * Adding 10.0.0.242 to resolv.conf"
# > to replace the file and >> to add to the end of the file
echo "nameserver 10.0.0.242" > /etc/resolv.conf
```

## Port Forwarding

If you enable port forwarding by adding `-e PORT_FORWARDING=true` to your container it will be opened to the outside. This is beneficial when seeding/uploading. On startup a port will be requested from Private Internet Access, this port will then be opened on the containers firewall and added to the qBittorrent config. qBittorrent will then bind to that port on launch.

You can not specify a port, Private Internet Access assign a random port to your connection that will change every time. The port will be assigned for a maximum of 2 months. The container will have to keep in contact with PIA to keep the port alive and the port may be revoke if the container is not able to keep in contact. 

If the internet connection is lossed for a short time, the port remains open.  
If the internet connection is lost for longer than 15 minutes the port should remain open until the port is reassigned. Although the container is designed to restart if there is an issue with port forwarding (exit code 5), i have yet to experience a port becoming unavailable. If you seem to have an issue, restart the container or goto File and use the exit qBittorrent from the webUI. The container will restart if `--restart unless-stopped` is set .

## Connect to webUI

You can connect via your web browser using http://127.0.0.1:8888 or you public ip / LAN if you have forwarding set up

Default username: admin  
Default Password: (A temporary password is provided in the docker logs `docker logs pia`)

You should change the default password as it will change every time the container is restarted. To change the default password first login to your UI by going to [http://127.0.0.1:8888](http://127.0.0.1:8888) Once logged in click 'Tools' at the top and then 'Options@. Now in the Options panel click the 'Web UI' tab and under 'Authentication' you can change the username and password. Then scroll to the bottom and save.

## Hooks

If you need to extend what is happening with the container, you can create a shell script hook in `/config` (looking from perspective of container so whichever place you mapped to it) called `post-vpn-connect.sh`. The code will run just after OpenVPN connects but before qBitTorrent starts. A good place to update tracker security with your new IP etc.

The script runs as the root user and can install applications via apk/apt, edit the iptables if needed and use variables from the main script. Variables from the main script should not be change as this may cause issues with the port forwarding, but you can happily read them and use them in your code. 

|    variable   | Description                                                                    |
|---------------|--------------------------------------------------------------------------------|
| `PF_PORT`     | The forwarding port given to you by Private Internet Access for this connection|
| `WEBUI_PORT`  | The local web UI port when connecting to qBittorrent                           |
| `UID`         | The local user id that qBittorrent uses to write files                         |
| `GID`         | The local group id that qBittorrent uses to write files                        |

Basic script for latest or alpine
```bash
# Get my external ip and save it to a var
MY_IP=$(wget -qO- ifconfig.me/ip)
# print my external ip we have just saved
printf " My IP is $MY_IP\n"
# print my forwarding port the main script requested from Private Internet Access
printf " My forwarding port is $PF_PORT\n"
```
Basic script for ubuntu
```bash
# Get my external ip and save it to a var
MY_IP=$(wget -qO- ifconfig.me/ip)
# print my external ip we have just saved
printf " My IP is $MY_IP\n"
# print my forwarding port the main script requested from Private Internet Access
printf " My forwarding port is $PF_PORT\n"
```

Use caution with blocking loops as this script must finish before qBittorrent is started.

## For the paranoids

- You can review the code which essential consists in the [Dockerfile](https://github.com/j4ym0/pia-qbittorrent-docker/blob/master/Dockerfile) and [entrypoint.sh](https://github.com/j4ym0/pia-qbittorrent-docker/blob/master/entrypoint.sh)
- Any issues please raise them!!
- Build the images straight from git:

    ```bash
    docker build -t j4ym0/pia-qbittorrent https://github.com/j4ym0/pia-qbittorrent-docker.git
    ```

- clone the repository and build:

    ```bash
    git clone https://github.com/j4ym0/pia-qbittorrent-docker.git
    cd pia-qbittorrent-docker
    docker build -t j4ym0/pia-qbittorrent .
    ```

- Using docker compose:

  ```bash
    git clone https://github.com/j4ym0/pia-qbittorrent-docker.git
    cd pia-qbittorrent-docker
    docker-compose up -d
  ```

- The download and unziping of PIA openvpn files is done at build for the ones not able to download the zip files
- Checksums for PIA openvpn zip files are not used as these files change often (but HTTPS is used)
- PIA Nextgen servers are used
- DNS Leaks tests seems to be ok, NEED FEEDBACK

## Known Issues

- **Using special character in password** - [Issue #39](https://github.com/j4ym0/pia-qbittorrent-docker/issues/39)
  - If your password contains special character you may need to use a backslash ( \ ) to prevent the character from functioning as a special character in terminal.
  - This is down to the terminal, shell or OS you are using. Special character are usually $"<=>?; but this will depend on your terminal, shell or OS, so if you are stuck on waiting to connect please check.
  - **Fix**: if your password is Pa$$w<>rd? this would become Pa\\$\\$w\\<\\>rd\\?

- **Unauthorized when using proxy for WebUI** - [Issue #26](https://github.com/j4ym0/pia-qbittorrent-docker/issues/26)
  - This can happen when using a proxy to access the WebUI or accessing from a different port to the one configured. 
  - The issue is a security feature CSRF Protection and can be disabled.
  - **Fix**: Disable CSRF Protection `-e CSRFPROTECTION=false`

- **nft: Protocol not supported** - [Issue #16](https://github.com/j4ym0/pia-qbittorrent-docker/issues/16)
  - This will happen if the host device does not have the package nftables, usually installed with the newer iptables. 
  - Known to be a issue with synology NAS
  - **Fix**: Set LEGACY_IPTABLES to true `-e LEGACY_IPTABLES=true`

- **5.x not deleting files, Moving to folder .trash-x**
  - qBittrorrent v5.0.0 introduce "Torrent content removing mode" default option is to move files to trash(if possible). 
  - torrent data is moved and no deleted and can be changed in the options
  - **Fix**: Go to Tools -> Options... -> Advanced (tab) and set Torrent content removing mode to delete files permanently. Click save and delete the /downloads/.trash-* folder

## TODOs

- More DNS leak testing
- Edit config from environment vars

## License

This repository is under an [MIT license](https://github.com/j4ym0/pia-qbittorrent-docker/master/license)
