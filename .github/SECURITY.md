# Security Policy

## Supported Versions

Only the latest released image receives security updates. The `:latest` tag always points to the most recent `vX.Y.Z` release — pull it to stay current. Older tags are not patched.

## Reporting a Vulnerability

Please report security vulnerabilities **privately** using GitHub's [Private Vulnerability Reporting](https://github.com/GeorgeAL78/pia-qbittorrent-docker/security/advisories/new). Do **not** open a public issue for security problems.

For regular (non-security) bugs, use the normal [issue tracker](https://github.com/GeorgeAL78/pia-qbittorrent-docker/issues).

## Scope

This project packages upstream software (qBittorrent, libtorrent, OpenVPN, WireGuard) into a Docker container. Vulnerabilities in those upstream projects should be reported to their respective maintainers. This policy covers the container's own scripts and configuration — `Dockerfile`, `entrypoint.sh`, `healthcheck.sh`, and the bundled config.
