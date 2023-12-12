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
- [OpenVPN 2.6.1](https://packages.ubuntu.com/bionic/openvpn) to tunnel to PIA nextgen servers
- [IPtables 1.8.7](https://packages.ubuntu.com/bionic/iptables) enforces the container to communicate only through the VPN or with other containers in its virtual network (acts as a killswitch)

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


## Setup

1. <details><summary>Requirements</summary><p>

    - A Private Internet Access **username** and **password** - [Sign up referral link](http://www.privateinternetaccess.com/pages/buy-a-vpn/1218buyavpn?invite=U2FsdGVkX1-Ki-3bKiIknvTQB1F-2Tz79e8QkNeh5Zc%2CbPOXkZjc102Clh5ih5-Pa_TYyTU)
    - External firewall requirements, if you have one
        - Allow outbound TCP 853 to 1.1.1.1 to allow Unbound to resolve the PIA domain name at start. You can then block it once the container is started.
        - For UDP normal encryption, allow outbound UDP 1198
        - For the built-in web HTTP proxy, allow inbound TCP 8888
    - Docker API 1.25 to support `init`

    </p></details>

1. Launch the container with:

    ```bash
    docker run -d --init --name=pia --cap-add=NET_ADMIN -v /My/Downloads/Folder/:/downloads \
    -p 8888:8888 -e REGION="Netherlands" -e USER=xxxxxxx -e PASSWORD=xxxxxxxx \
    j4ym0/pia-qbittorrent
    ```

    Note that you can:
    - Change the many [environment variables](#environment-variables) available
    - Use `-p 8888:8888/tcp` to access the HTTP web proxy
    - Pass additional arguments to *openvpn* using Docker's command function (commands after the image name)

## Testing

Check the PIA IP address matches your expectations

try [http://checkmyip.torrentprivacy.com/](http://checkmyip.torrentprivacy.com/)

## Environment variables

| Environment variable | Default | Description                                                                    |
|----------------------| --- |--------------------------------------------------------------------------------|
| `REGION`             | `Netherlands` | One of the [PIA regions](https://www.privateinternetaccess.com/pages/network/) |
| `USER`               | | Your PIA username                                                              |
| `PASSWORD`           | | Your PIA password                                                              |
| `VPN`                | `openvpn` | chose to use the openvpn or wireguard                                                              |
| `WEBUI_PORT`         | `8888` | `1024` to `65535` internal port for HTTP proxy                                 |
| `DNS_SERVERS`        | `209.222.18.222,209.222.18.218,103.196.38.38,103.196.38.39` | DNS servers to use, comma separated                                            
| `UID`                | | The UserID (default 700)                                                       |
| `GID`                | | The GroupID (default 700)                                                      |
| `TZ`                 | | The Timzeone                                                                   |

To get the user id, run `id -u USER`
To get the group id for a user, run `id -g USER`
PIA DNS Servers 209.222.18.222 and 209.222.18.218
Handshake DNS Servers 103.196.38.38 and 103.196.38.39

## Connect to it

You can connect via your web browser using http://127.0.0.1:8888 or you public ip / LAN if you have forwarding set up

Default username: admin
Default Password: adminadmin

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
