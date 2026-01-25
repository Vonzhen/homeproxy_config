#!/bin/sh

[ -f "/etc/hpcc/env.conf" ] || exit 1
source /etc/hpcc/env.conf

TICK_FILE="/etc/hpcc/last_tick"
LOCK_FILE="/tmp/hp_watchdog.lock"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    exit 1
fi

REMOTE_TICK=$(curl -skL --connect-timeout 10 "https://$CF_DOMAIN/tg-sync?token=$CF_TOKEN")

[ -z "$REMOTE_TICK" ] || [ "$REMOTE_TICK" = "Unauthorized" ] && exit 1

LAST_TICK=$(cat "$TICK_FILE" 2>/dev/null || echo "0")

if [ "$REMOTE_TICK" -gt "$LAST_TICK" ] 2>/dev/null; then
    echo "$REMOTE_TICK" > "$TICK_FILE"
    
    /bin/sh /etc/hpcc/bin/hp_download.sh >/dev/null 2>&1
    /bin/sh /etc/hpcc/bin/hp_config_update.sh >/dev/null 2>&1
fi
