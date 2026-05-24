#!/bin/sh
# Refresh UnblockNeteaseMusic IP Address List

NAME="unblockneteasemusic"
RUN_DIR="/var/run/$NAME"
LOG="$RUN_DIR/run.log"

# Ensure log directory exists
mkdir -p "$RUN_DIR"

echo "$(date '+%Y-%m-%d %H:%M:%S') [START] Refreshing Netease IPs" >> "$LOG"

# 1. Get latest IPs from Netease
NETEASE_JSON=$(curl --connect-timeout 10 -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" "http://httpdns.n.netease.com/httpdns/v2/d?domain=music.163.com,interface.music.163.com,interface3.music.163.com,apm.music.163.com,apm3.music.163.com,clientlog.music.163.com,clientlog3.music.163.com" 2>&1)

if [ -z "$NETEASE_JSON" ]; then
    echo "$(date) [ERROR] Failed to get data from Netease DNS" >> "$LOG"
    exit 1
fi

# Debug: log raw response length
echo "$(date) [DEBUG] JSON length: ${#NETEASE_JSON}" >> "$LOG"

# 2. Parse IPv4 addresses
IPV4_LIST=$(echo "$NETEASE_JSON" | jsonfilter -e '@.data.*.ip.*' 2>/dev/null | sort -u | tr '\n' ' ' | sed 's/ $//')

if [ -n "$IPV4_LIST" ]; then
    echo "$(date) [DEBUG] IPv4 list: $IPV4_LIST" >> "$LOG"
    # Flush and refill set
    nft flush set inet fw4 neteasemusic 2>/dev/null
    for ip in $IPV4_LIST; do
        nft add element inet fw4 neteasemusic { $ip } 2>&1 | grep -v "exists" >> "$LOG"
    done
    COUNT_IPV4=$(echo $IPV4_LIST | wc -w)
    echo "$(date) [SUCCESS] Updated neteasemusic set with $COUNT_IPV4 IPv4 addresses" >> "$LOG"
else
    echo "$(date) [ERROR] No IPv4 addresses extracted" >> "$LOG"
fi

# 3. Parse IPv6 addresses  
IPV6_LIST=$(echo "$NETEASE_JSON" | jsonfilter -e '@.data.*.ipv6.*' 2>/dev/null | sort -u | tr '\n' ' ' | sed 's/ $//')

if [ -n "$IPV6_LIST" ]; then
    echo "$(date) [DEBUG] IPv6 list: $IPV6_LIST" >> "$LOG"
    nft flush set inet fw4 neteasemusic6 2>/dev/null
    for ip in $IPV6_LIST; do
        nft add element inet fw4 neteasemusic6 { $ip } 2>&1 | grep -v "exists" >> "$LOG"
    done
    COUNT_IPV6=$(echo $IPV6_LIST | wc -w)
    echo "$(date) [SUCCESS] Updated neteasemusic6 set with $COUNT_IPV6 IPv6 addresses" >> "$LOG"
else
    echo "$(date) [WARNING] No IPv6 addresses extracted" >> "$LOG"
fi

echo "$(date) [END] Refresh completed" >> "$LOG"