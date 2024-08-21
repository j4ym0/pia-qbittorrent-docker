# Private Internet Access Client (qBittorrent+OpenVPN+Iptables+DNS over TLS on alpine/ubuntu)
# Nextgen (GEN4) Server compatible

<p align="center">
  <a href="https://github.com/j4ym0/pia-qbittorrent-docker/releases">
    <img alt="latest version" src="https://img.shields.io/github/v/tag/j4ym0/pia-qbittorrent-docker.svg?style=flat-square" />
  </a>
  <a href="https://hub.docker.com/r/j4ym0/pia-qbittorrent">
    <img alt="Pulls from DockerHub" src="https://img.shields.io/docker/pulls/j4ym0/pia-qbittorrent.svg?style=flat-square" />
  </a>
</p>

> :warning: Your `qbittorrent.conf` may not be compatible with 4.4.0 and may need to be deleted 

*Lightweight qBittorrent & Private Internet Access VPN client*

[![PIA Docker OpenVPN](https://github.com/j4ym0/pia-qbittorrent-docker/raw/master/readme/title.png)](https://hub.docker.com/r/j4ym0/pia-qbittorrent/)



<details><summary>Click to show base components</summary><p>

- [Ubuntu 23.04](https://ubuntu.com) for a base image
- [Alpine 3.16.0](https://alpinelinux.org) for a base image
- [OpenVPN 2.5.6] Alpine (https://pkgs.alpinelinux.org/package/edge/main/x86_64/openvpn) to tunnel to PIA nextgen servers
- [OpenVPN 2.6.1] Ubuntu (https://packages.ubuntu.com/bionic/openvpn) to tunnel to PIA nextgen servers
- [IPtables 1.8.8](https://packages.ubuntu.com/bionic/iptables) enforces the container to communicate only through the VPN or with other containers in its virtual network (acts as a killswitch)

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
    - External firewall requirements, if you have one
        - Allow outbound TCP 853 to 1.1.1.1 to allow the resolve the PIA domain names at start. You can then block it once the container is started.
        - For VPN connection allow outbound UDP 1198
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

| Environment variable | Default | Description                                                                    |
|----------------------| --- |--------------------------------------------------------------------------------|
| `REGION`             | `Netherlands` | One of the [PIA regions](https://www.privateinternetaccess.com/pages/network/) |
| `USER`               | | Your PIA username                                                              |
| `PASSWORD`           | | Your PIA password                                                              |
| `PORT_FORWARDING`    | `false` | Set to `true` if you want to enable port forwarding from PIA                                                              |
| `WEBUI_PORT`         | `8888` | `1024` to `65535` internal port for HTTP proxy                                 |
| `DNS_SERVERS`        | `209.222.18.222,209.222.18.218,103.196.38.38,103.196.38.39` | DNS servers to use, comma separated                                            
| `UID`                | | The UserID (default 700)                                                       |
| `GID`                | | The GroupID (default 700)                                                      |
| `TZ`                 | | The Timzeone                                                                   |

Port forwarding port will be added to qBittorrent settings on startup. A port can last for up to 2 months.  
To get the user id, run `id -u USER`  
To get the group id for a user, run `id -g USER`  
PIA DNS Servers 209.222.18.222 and 209.222.18.218  
Handshake DNS Servers 103.196.38.38 and 103.196.38.39  

## Port Forwarding

If you enable port forwarding by adding `-e PORT_FORWARDING=true` your pia-qbittorrent, your container will be opened to the outside. This is beneficial when seeding/uploading. On startup a port will be requested from Private Internet Access, this port will then be opened on the containers firewall and added to the qBittorrent config. qBittorrent will then bind to that port on launch.

You can not specify a port, Private Internet Access assign a random port to your connection that will change every time. The port will be assigned for a maximum of 2 months. The container will have to keep in contact with PIA to keep the port alive and the port may be revoke if the container is not able to keep in contact. 

If the internet connection is lossed for a short time, the port remains open.  
If the internet connection is lost for longer than 15 minutes the port should remain open until the port is reassigned. Although the container is designed to restart if there is an issue with port forwarding (exit code 5), i have yet to experience a port becoming unavailable. If you seem to have an issue, restart the container or goto File and use the exit qBittorrent from the webUI. The container will restart if `--restart unless-stopped` is set .

## Connect to webUI

You can connect via your web browser using http://127.0.0.1:8888 or you public ip / LAN if you have forwarding set up

Default username: admin  
Default Password: (A temporary password is provided in the docker logs `docker logs pia`)


## Hooks

If you need to extend what is happening with the container, you can create a shell script hook in `/config` (looking from perspective of container so whichever place you mapped to it) called `post-vpn-connect.sh`. The code will run just after OpenVPN connects but before qBitTorrent starts. A good place to update tracker security with your new IP etc.

The script runs as the root user and can install applications via apk/apt, edit the iptables if needed and use variables from the main script. Variables from the main script should not be change as this may cause issues with the port forwarding, but you can happily read them and use them in your code. 

|    variable   | Description                                                                    |
|---------------|--------------------------------------------------------------------------------|
| `PF_PORT`     | The forwarding port given to you by Private Internet Access for this connection|
| `WEBUI_PORT`  | The local web UI port when connecting to qBittorrent                           |
| `UID`         | The local user id that qBittorrent uses to write files                         |
| `GID`         | The local group id that qBittorrent uses to write files                        |

Basic script
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

## TODOs

- More DNS leak testing
- Edit config from environment vars

## License

This repository is under an [MIT license](https://github.com/j4ym0/pia-qbittorrent-docker/master/license)
