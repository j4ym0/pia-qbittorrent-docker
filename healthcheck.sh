#!/bin/sh

# Check VPN interface exists
if ! ifconfig | grep -q 'tun0\|pia'; then
    echo "No VPN interface found" >&2
    exit 1
fi

# Check web UI
HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" --max-time 5 "http://localhost:${WEBUI_PORT}" 2>/dev/null)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
    exit 0
fi

# Retry with HTTPS if HTTP failed
HTTPS_CODE=$(curl -o /dev/null -s -k --max-time 5 "https://localhost:${WEBUI_PORT}" 2>/dev/null)
if [ "$HTTPS_CODE" = "200" ] || [ "$HTTPS_CODE" = "401" ] || [ "$HTTPS_CODE" = "403" ]; then
    exit 0
fi

echo "Web UI not responding on port ${WEBUI_PORT}" >&2
exit 1
