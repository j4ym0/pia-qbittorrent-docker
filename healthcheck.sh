#!/bin/sh

# Check for tunnel 
ifconfig | grep -cs 'tun0' > /dev/null 2>&1
if [ $? -eq 0 ]; then
    # check qBittorrent is responding on web ui port
    if [ "$(curl -o /dev/null -s -w "%{http_code}\n" http://localhost:$WEBUI_PORT)" -eq "200" ]; then
        exit 0
    fi
fi

exit 1