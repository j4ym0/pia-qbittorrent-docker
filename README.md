<div align="center">

## qBittorrent & Private Internet Access VPN Docker

[![Latest Version](https://img.shields.io/github/v/tag/GeorgeAL78/pia-qbittorrent-docker)](https://github.com/GeorgeAL78/pia-qbittorrent-docker/releases)
[![Docker Pulls](https://img.shields.io/docker/pulls/gjergjk/pia-qbittorrent)](https://hub.docker.com/r/gjergjk/pia-qbittorrent)

</div>

A Docker container combining **qBittorrent** with **Private Internet Access (PIA) VPN**, supporting both **WireGuard** and **OpenVPN**. Built on Alpine Linux for a minimal footprint.

> Fork of [j4ym0/pia-qbittorrent](https://hub.docker.com/r/j4ym0/pia-qbittorrent) with bug fixes and additional features.

---

## Features

- WireGuard and OpenVPN support
- PIA port forwarding for seeding
- Kill switch — all traffic blocked if VPN drops
- Configurable UID/GID for correct file ownership on Unraid and NAS systems
- Configurable UMASK for download folder permissions
- DNS leak protection with custom DNS servers
- qBittorrent network interface locked to VPN tunnel by default
- Web UI accessible on your local network
- Hook script support after VPN connects

---

## Components

| Component | Version |
|-----------|---------|
| Alpine Linux | 3.23 |
| qBittorrent | 5.2.1 |
| libtorrent | 2.0.11 |
| Boost | 1.86.0 |
| OpenVPN | 2.6.20 |
| WireGuard | 1.0.20250521 |
| IPTables | 1.8.11 |

---

## Quick Start

```bash
docker run -d --init --name=pia-qbittorrent --restart unless-stopped \
  --cap-add=NET_ADMIN \
  -v /your/downloads:/downloads \
  -v /your/config:/config \
  -p 8888:8888 \
  -e PIA_USERNAME=your_username \
  -e PIA_PASSWORD=your_password \
  -e PIA_REGION=ca_montreal \
  -e VPN_CLIENT=wireguard \
  -e UID=99 \
  -e GID=100 \
  -e UMASK=000 \
  gjergjk/pia-qbittorrent:latest
```

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PIA_USERNAME` | | PIA account username |
| `PIA_PASSWORD` | | PIA account password |
| `PIA_REGION` | `netherlands` | VPN region — see [PIA Servers](#pia-regions) |
| `VPN_CLIENT` | `openvpn` | VPN client: `openvpn` or `wireguard` |
| `PORT_FORWARDING` | `false` | Enable PIA port forwarding (recommended for seeding) |
| `UID` | `700` | User ID for qBittorrent process. Use `99` for Unraid |
| `GID` | `700` | Group ID for qBittorrent process. Use `100` for Unraid |
| `UMASK` | `022` | Umask for downloads. `000` = fully open, `002` = group-writable |
| `WEBUI_PORT` | `8888` | qBittorrent Web UI port |
| `WEBUI_INTERFACES` | | Network interfaces for Web UI access e.g. `eth0,eth1` |
| `DNS_SERVERS` | `9.9.9.9,149.112.112.112` | Comma-separated DNS servers |
| `LEGACY_IPTABLES` | `false` | Use legacy iptables instead of nftables |
| `TZ` | | Timezone e.g. `America/New_York` |
| `HOSTHEADERVALIDATION` | | Set to `false` if having trouble accessing the WebUI |
| `CSRFPROTECTION` | | Set to `false` if having trouble accessing the WebUI |

---

## Volumes

| Path | Description |
|------|-------------|
| `/downloads` | Download directory |
| `/config` | qBittorrent config and profiles |

---

## Unraid Setup

Set the following container variables for correct file ownership:

| Variable | Value |
|----------|-------|
| `UID` | `99` |
| `GID` | `100` |
| `UMASK` | `000` |

This maps qBittorrent to Unraid's `nobody:users` so downloaded files are accessible from SMB shares.

---

## VPN Client

### WireGuard
- Lower CPU usage and faster speeds due to less overhead
- Requires Linux kernel 5.6+
- Port forwarding works in most regions but may have issues in some
- Best for stable home networks

### OpenVPN
- Broader compatibility
- Better for unusual network configurations or high latency
- More reliable port forwarding

> **Note:** Port forwarding is only available in certain PIA regions. Canadian and European regions generally work best. US regions do not support port forwarding.

---

## PIA Regions

Common regions with port forwarding support:

| Region ID | Name |
|-----------|------|
| `ca_montreal` | CA Montreal |
| `ca_toronto` | CA Toronto |
| `ca_ontario` | CA Ontario |
| `netherlands` | Netherlands |
| `sweden` | SE Stockholm |
| `uk` | UK London |

Full list available at runtime — check the `data.json` in this repo.

---

## Port Forwarding

Enable with `-e PORT_FORWARDING=true`. On startup a port is requested from PIA, opened in the firewall, and set in qBittorrent automatically.

- Port is assigned randomly by PIA — you cannot specify one
- Port is valid for up to 2 months
- Container refreshes the port binding every 10 minutes to keep it alive
- If the container restarts too frequently (20+ times in 30 mins) you may hit PIA's rate limit — stop the container and wait 1 hour

---

## Web UI

Access at `http://YOUR_SERVER_IP:8888`

Default username: `admin`
Default password: shown in container logs (`docker logs pia-qbittorrent`)

> Change the password after first login — it changes every restart until you set a permanent one.

---

## auth.conf File

Store credentials securely by mounting an auth file instead of using environment variables:

```
/your/auth.conf:
line 1: your_pia_username
line 2: your_pia_password
```

```bash
docker run ... -v /your/auth.conf:/auth.conf ...
```

When `/auth.conf` is present, `PIA_USERNAME` and `PIA_PASSWORD` are ignored.

---

## Hooks

Create `/config/post-vpn-connect.sh` to run custom code after the VPN connects but before qBittorrent starts. Runs as root.

Available variables:

| Variable | Description |
|----------|-------------|
| `PF_PORT` | The PIA forwarded port |
| `WEBUI_PORT` | The Web UI port |
| `PUID` | The user ID qBittorrent runs as |
| `PGID` | The group ID qBittorrent runs as |

Example:
```bash
MY_IP=$(wget -qO- ifconfig.me/ip)
printf " My external IP is $MY_IP\n"
printf " My forwarding port is $PF_PORT\n"
```

---

## DNS Servers

| Server | Provider |
|--------|----------|
| `9.9.9.9`, `149.112.112.112` | Quad9 |
| `1.1.1.1`, `1.0.0.1` | Cloudflare |
| `8.8.8.8`, `8.8.4.4` | Google |
| `84.200.69.80`, `84.200.70.40` | DNS.WATCH |

Once connected to PIA you can also use PIA's private DNS: `10.0.0.242`

---

## Build from Source

```bash
git clone https://github.com/GeorgeAL78/pia-qbittorrent-docker.git
cd pia-qbittorrent-docker
docker build -t gjergjk/pia-qbittorrent .
```

---

## Known Issues

- **Banned client error on some trackers**
  - Some private trackers may not have whitelisted the current qBittorrent version yet
  - Check the tracker's forum for supported client versions

- **Port forwarding rate limit**
  - If the container restarts more than 20 times in 30 minutes, PIA will rate limit port forwarding requests
  - **Fix**: Stop the container and wait 1 hour

- **Special characters in password**
  - If your password contains special characters use the `/auth.conf` file instead of environment variables

- **Unauthorized when using proxy for WebUI**
  - **Fix**: Set `CSRFPROTECTION=false`

- **nft: Protocol not supported**
  - Occurs on older kernels or Synology NAS
  - **Fix**: Set `LEGACY_IPTABLES=true`

- **Files moved to .trash instead of deleted**
  - qBittorrent 5.x defaults to moving files to trash
  - **Fix**: Tools → Options → Advanced → set "Torrent content removing mode" to "Delete files permanently"

---

## Changelog

See [Docker Hub](https://hub.docker.com/r/gjergjk/pia-qbittorrent) for full changelog.

---

## License

[MIT License](LICENSE)
