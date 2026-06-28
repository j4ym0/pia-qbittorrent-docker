<div align="center">

<img src="readme/icon.png" width="120" alt="pia-qbittorrent logo">

## qBittorrent & Private Internet Access VPN Docker

[![CI](https://img.shields.io/github/actions/workflow/status/GeorgeAL78/pia-qbittorrent-docker/docker-publish.yml?label=CI&logo=github)](https://github.com/GeorgeAL78/pia-qbittorrent-docker/actions)
[![License](https://img.shields.io/github/license/GeorgeAL78/pia-qbittorrent-docker)](LICENSE)
[![qBittorrent](https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fraw.githubusercontent.com%2FGeorgeAL78%2Fpia-qbittorrent-docker%2Fmaster%2FDockerfile&search=release-%28%5Cd%2B%5C.%5Cd%2B%5C.%5Cd%2B%29&replace=%241&label=qBittorrent&color=2186c4&logo=qbittorrent)](https://github.com/qbittorrent/qBittorrent/releases)
[![Unraid CA](https://img.shields.io/badge/Unraid-Community%20Apps-orange)](https://ca.unraid.net/apps/search?query=pia-qbittorrent)

[![Docker Pulls](https://img.shields.io/docker/pulls/gjergjk/pia-qbittorrent?logo=docker)](https://hub.docker.com/r/gjergjk/pia-qbittorrent)
[![Docker Stars](https://img.shields.io/docker/stars/gjergjk/pia-qbittorrent?logo=docker)](https://hub.docker.com/r/gjergjk/pia-qbittorrent)
[![Image Size](https://img.shields.io/docker/image-size/gjergjk/pia-qbittorrent/latest?logo=docker&label=image%20size)](https://hub.docker.com/r/gjergjk/pia-qbittorrent/tags)

[![Latest Tag](https://img.shields.io/github/v/tag/GeorgeAL78/pia-qbittorrent-docker?label=latest%20release)](https://github.com/GeorgeAL78/pia-qbittorrent-docker/releases)
[![Release Date](https://img.shields.io/github/release-date/GeorgeAL78/pia-qbittorrent-docker)](https://github.com/GeorgeAL78/pia-qbittorrent-docker/releases)
[![Commits Since](https://img.shields.io/github/commits-since/GeorgeAL78/pia-qbittorrent-docker/latest)](https://github.com/GeorgeAL78/pia-qbittorrent-docker/commits/master)
[![Last Commit](https://img.shields.io/github/last-commit/GeorgeAL78/pia-qbittorrent-docker)](https://github.com/GeorgeAL78/pia-qbittorrent-docker/commits/master)

[![Open Issues](https://img.shields.io/github/issues/GeorgeAL78/pia-qbittorrent-docker)](https://github.com/GeorgeAL78/pia-qbittorrent-docker/issues)
[![Code Size](https://img.shields.io/github/languages/code-size/GeorgeAL78/pia-qbittorrent-docker)](https://github.com/GeorgeAL78/pia-qbittorrent-docker)
[![Repo Size](https://img.shields.io/github/repo-size/GeorgeAL78/pia-qbittorrent-docker)](https://github.com/GeorgeAL78/pia-qbittorrent-docker)
[![Top Language](https://img.shields.io/github/languages/top/GeorgeAL78/pia-qbittorrent-docker)](https://github.com/GeorgeAL78/pia-qbittorrent-docker)

</div>

A Docker container combining **qBittorrent** with **Private Internet Access (PIA) VPN**, supporting both **WireGuard** and **OpenVPN**. Built on Alpine Linux for a minimal footprint.

> Fork of [j4ym0/pia-qbittorrent](https://hub.docker.com/r/j4ym0/pia-qbittorrent) with bug fixes and additional features.

## Quick Links

| | | |
|---|---|---|
| 🚀 [Quick Start](#quick-start) | ⚙️ [Environment Variables](#environment-variables) | 🌍 [PIA Regions](#pia-regions) |
| 🔀 [Port Forwarding](#port-forwarding) | 🌐 [VPN Client](#vpn-client) | 🧭 [DNS Servers](#dns-servers) |
| 🖥️ [Unraid Setup](#unraid-setup) | 🔐 [auth.conf File](#authconf-file) | 🪝 [Hooks](#hooks) |
| 💾 [Saving .torrent Files](#saving-torrent-files) | 🧩 [Companion App](#companion-app) | ❓ [Known Issues](#known-issues) |
| 🐛 [Report a Bug](https://github.com/GeorgeAL78/pia-qbittorrent-docker/issues) | 📦 [Releases](https://github.com/GeorgeAL78/pia-qbittorrent-docker/releases) | 🐳 [Docker Hub](https://hub.docker.com/r/gjergjk/pia-qbittorrent) |

---

## Features

- WireGuard and OpenVPN support
- PIA port forwarding for seeding
- Kill switch — all IPv4 and IPv6 traffic blocked if the VPN drops
- Multi-arch images — `amd64` and `arm64`
- VPN network interface auto-detected and locked (WireGuard `pia` / OpenVPN `tun0`)
- Configurable UID/GID for correct file ownership on Unraid and NAS systems
- Configurable UMASK; download folder permissions preserved across restarts
- Automatic `.torrent` file export to `/downloads/torrents`
- Graceful shutdown — saves resume data so torrents resume instead of re-checking after an update
- Secure credential storage via `auth.conf`
- DNS leak protection with custom DNS servers
- Hook script support after the VPN connects
- Web UI accessible on your local network

---

## Components

| Component | Version |
|-----------|---------|
| Alpine Linux | 3.23 |
| qBittorrent | 5.2.2 |
| libtorrent | 2.0.12 |
| Boost | 1.91.0 |
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
| `PORT_FORWARDING` | `true` | Enable PIA port forwarding for seeding. Falls back gracefully if your region doesn't support it |
| `UID` | `700` | User ID for qBittorrent process. Use `99` for Unraid |
| `GID` | `700` | Group ID for qBittorrent process. Use `100` for Unraid |
| `UMASK` | `022` | Umask for downloads. `000` = fully open, `002` = group-writable |
| `WEBUI_PORT` | `8888` | qBittorrent Web UI port |
| `WEBUI_INTERFACES` | | Network interfaces for Web UI access e.g. `eth0,eth1` |
| `ALLOW_LOCAL_SUBNET_TRAFFIC` | `false` | Allow LAN devices to connect directly to the container |
| `EXTRA_SUBNETS` | | Comma-separated extra subnets to allow through the kill switch (e.g. for reverse proxies or *arr apps on a different Docker network) |
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

**Network type:** leave it on **Bridge** (the Unraid default). The VPN tunnel runs entirely inside the container, so no special network mode is needed.

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

> **Note:** Port forwarding is available in most PIA regions, but not all. See the [PIA Regions](#pia-regions) section for the full list of regions that support it.

---

## PIA Regions

Set `PIA_REGION` to the region you want. Matching is **flexible** — you can use the region name or its PIA ID, and it's case-insensitive (underscores, hyphens, and spaces are treated the same). So `ca_montreal`, `CA Montreal`, and `ca` all resolve to the same region.

Common regions **with port forwarding**:

| `PIA_REGION` | Location |
|--------------|----------|
| `ca_montreal` | CA Montreal |
| `ca_toronto` | CA Toronto |
| `ca_ontario` | CA Ontario |
| `uk` | UK London |
| `netherlands` | Netherlands |
| `de_frankfurt` | DE Frankfurt |
| `france` | France |
| `switzerland` | Switzerland |
| `sweden` | SE Stockholm |
| `spain` | ES Madrid |
| `italy` | IT Milano |
| `romania` | Romania |
| `singapore` | Singapore |
| `japan` | JP Tokyo |
| `aus` | AU Sydney |

> ℹ️ **Most PIA regions support port forwarding, but not all.** The regions listed above are confirmed to support it. To use a different region with `PORT_FORWARDING=true`, see the full list of port-forwarding regions below.

### All port-forwarding regions

<details>
<summary><h3>🌍 &nbsp;Click to view all 111 port-forwarding regions</h3></summary>

| Location | `PIA_REGION` |
|----------|--------------|
| AU Adelaide | `au_adelaide-pf` |
| AU Brisbane | `au_brisbane-pf` |
| AU Melbourne | `aus_melbourne` |
| AU Perth | `aus_perth` |
| AU Sydney | `aus` |
| Albania | `al` |
| Algeria *(geo)* | `dz` |
| Andorra *(geo)* | `ad` |
| Argentina | `ar` |
| Armenia *(geo)* | `yerevan` |
| Australia Streaming Optimized | `au_australia-so` |
| Austria | `austria` |
| Bahamas *(geo)* | `bahamas` |
| Bangladesh *(geo)* | `bangladesh` |
| Belgium | `belgium` |
| Bolivia *(geo)* | `bo_bolivia-pf` |
| Bosnia and Herzegovina *(geo)* | `ba` |
| Brazil | `br` |
| Bulgaria | `sofia` |
| CA Montreal | `ca` |
| CA Ontario | `ca_ontario` |
| CA Ontario Streaming Optimized | `ca_ontario-so` |
| CA Toronto | `ca_toronto` |
| CA Vancouver | `ca_vancouver` |
| Cambodia *(geo)* | `cambodia` |
| Chile | `santiago` |
| China *(geo)* | `china` |
| Colombia | `bogota` |
| Costa Rica *(geo)* | `sanjose` |
| Croatia | `zagreb` |
| Cyprus *(geo)* | `cyprus` |
| Czech Republic | `czech` |
| DE Berlin | `de_berlin` |
| DE Frankfurt | `de-frankfurt` |
| DE Germany Streaming Optimized | `de_germany-so` |
| DK Streaming Optimized | `denmark_2` |
| Denmark | `denmark` |
| ES Madrid | `spain` |
| ES Valencia | `es-valencia` |
| Ecuador *(geo)* | `ec_ecuador-pf` |
| Egypt *(geo)* | `egypt` |
| Estonia | `ee` |
| FI Helsinki | `fi` |
| FI Streaming Optimized | `fi_2` |
| France | `france` |
| Georgia *(geo)* | `georgia` |
| Greece | `gr` |
| Greenland *(geo)* | `greenland` |
| Guatemala *(geo)* | `gt_guatemala-pf` |
| Hong Kong *(geo)* | `hk` |
| Hungary | `hungary` |
| IT Milano | `italy` |
| IT Streaming Optimized | `italy_2` |
| Iceland | `is` |
| India *(geo)* | `in` |
| Indonesia *(geo)* | `jakarta` |
| Ireland | `ireland` |
| Isle of Man *(geo)* | `man` |
| Israel | `israel` |
| JP Streaming Optimized | `japan_2` |
| JP Tokyo | `japan` |
| Kazakhstan *(geo)* | `kazakhstan` |
| Latvia | `lv` |
| Liechtenstein *(geo)* | `liechtenstein` |
| Lithuania | `lt` |
| Luxembourg | `lu` |
| Macao *(geo)* | `macau` |
| Malaysia | `kualalumpur` |
| Malta *(geo)* | `malta` |
| Mexico | `mexico` |
| Moldova | `md` |
| Monaco *(geo)* | `monaco` |
| Mongolia *(geo)* | `mongolia` |
| Montenegro *(geo)* | `montenegro` |
| Morocco *(geo)* | `morocco` |
| NL Netherlands Streaming Optimized | `nl_netherlands-so` |
| Nepal *(geo)* | `np_nepal-pf` |
| Netherlands | `nl_amsterdam` |
| New Zealand | `nz` |
| Nigeria *(geo)* | `nigeria` |
| North Macedonia | `mk` |
| Norway | `no` |
| Panama *(geo)* | `panama` |
| Peru *(geo)* | `pe_peru-pf` |
| Philippines *(geo)* | `philippines` |
| Poland | `poland` |
| Portugal | `pt` |
| Qatar *(geo)* | `qatar` |
| Romania | `ro` |
| SE Stockholm | `sweden` |
| SE Streaming Optimized | `sweden_2` |
| Saudi Arabia *(geo)* | `saudiarabia` |
| Serbia | `rs` |
| Singapore | `sg` |
| Slovakia | `sk` |
| Slovenia | `slovenia` |
| South Africa | `za` |
| South Korea | `kr_south_korea-pf` |
| Sri Lanka *(geo)* | `srilanka` |
| Switzerland | `swiss` |
| Taiwan | `taiwan` |
| Turkey *(geo)* | `tr` |
| UK London | `uk` |
| UK Manchester | `uk_manchester` |
| UK Southampton | `uk_southampton` |
| UK Streaming Optimized | `uk_2` |
| Ukraine *(geo)* | `ua` |
| United Arab Emirates | `ae` |
| Uruguay *(geo)* | `uy_uruguay-pf` |
| Venezuela *(geo)* | `venezuela` |
| Vietnam *(geo)* | `vietnam` |

*Regions marked* (geo) *are geo-located — the server is physically elsewhere but presents that country's IP. They still support port forwarding.*

</details>

This list comes directly from PIA and is refreshed into the image at build time, so the bundled `data.json` always matches PIA's current servers. To regenerate the readable list yourself:

```bash
curl -s https://serverlist.piaservers.net/vpninfo/servers/v6 | head -1 | \
  jq -r '.regions[] | select(.port_forward) | "\(.name) — \(.id)"' | sort
```

---

## Port Forwarding

**Enabled by default** (`PORT_FORWARDING=true`). On startup a port is requested from PIA, opened in the firewall, and set in qBittorrent automatically.

- Port is assigned randomly by PIA — you cannot specify one
- Port is valid for up to 2 months
- Container refreshes the port binding every 10 minutes to keep it alive
- **If your region doesn't support port forwarding (e.g. all US regions), the container logs a warning and keeps running without it** — it no longer crashes. Pick a [supported region](#pia-regions) to use it.
- If the container restarts too frequently (20+ times in 30 mins) you may hit PIA's rate limit — stop the container and wait 1 hour

---

## Web UI

Access at `http://YOUR_SERVER_IP:8888`

Default username: `admin`
Default password: shown in container logs (`docker logs pia-qbittorrent`)

> Change the password after first login — it changes every restart until you set a permanent one.

---

## Saving .torrent Files

By default, added `.torrent` files are automatically saved to `/downloads/torrents` so you always keep a copy. The folder is created automatically when you add your first torrent.

**Magnet links** are saved too — just a few seconds later. A magnet has no metadata when added, so qBittorrent writes the `.torrent` once it fetches the metadata from the swarm. (If a magnet never finds peers, no file is written — but it wouldn't download anyway.)

> **Existing installs:** this default is only written on a **fresh** config, so if you upgraded from an earlier version it won't appear automatically. To enable it manually, go to **Options → Downloads → Saving Management**, tick **"Copy .torrent files to:"**, enter `/downloads/torrents`, and Save.

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

## Companion App

Looking for a native Windows desktop experience? Check out the companion Electron app that wraps the qBittorrent Web UI:

**[qBittorrent Desktop for Windows 11](https://github.com/GeorgeAL78/qbittorrent-desktop)** — native window, system tray, magnet link support, and `.torrent` file association.

---

## License

[GNU General Public License v3.0](LICENSE)

This project is a fork of [j4ym0/pia-qbittorrent](https://github.com/j4ym0/pia-qbittorrent), originally MIT licensed. The original MIT notice is preserved in the [NOTICE](NOTICE) file.

---

## Disclaimer

This is an unofficial, community-maintained project. It is **not affiliated with, endorsed by, or sponsored by** Private Internet Access or qBittorrent. "Private Internet Access", "PIA", and "qBittorrent" are trademarks of their respective owners and are used here only to describe compatibility.
