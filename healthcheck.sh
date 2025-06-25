#!/bin/sh

# Check for tunnel 
ifconfig | grep -cs 'tun0' > /dev/null 2>&1
if [ $? -eq 0 ]; then
    # check qBittorrent is responding on web ui port
    HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}\n" http://localhost:$WEBUI_PORT)

    if [ "$HTTP_CODE" -eq "200" ]; then
        exit 0
    elif [ "$HTTP_CODE" -eq "000" ]; then
        # Retry check with HTTPS (in case SSL enabled in qBittorrent GUI)
        if [ "$(curl -o /dev/null -s -w "%{http_code}\n" -k https://localhost:$WEBUI_PORT)" -eq "200" ]; then
            exit 0
        fi
    fi
fi

exit 1