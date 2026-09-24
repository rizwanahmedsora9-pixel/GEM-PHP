#!/data/data/com.termux/files/usr/bin/sh

PREFIX="/data/data/com.termux/files/usr"
export PATH="$PREFIX/bin:$PATH"

echo "[+] Initializing Stable DHCP & DNS Watchdog..."

pkill dnsmasq 2>/dev/null
pkill -f "php -S 0.0.0.0:8080" 2>/dev/null

echo "[+] Waiting for Android Hotspot interface..."
IFACE=""
while [ -z "$IFACE" ]; do
    IFACE=$(ip link | grep -E -o 'ap[0-9]|swlan[0-9]|wlan[0-9]|rndis[0-9]' | head -n 1)
    sleep 1
done

echo "[+] Hotspot Interface locked: $IFACE"

# Get Gateway IP
GW_IP=$(ip addr show "$IFACE" | grep "inet " | awk '{print $2}' | cut -d/ -f1)
[ -z "$GW_IP" ] && GW_IP="192.168.43.1"

sysctl -w net.ipv4.ip_forward=1 > /dev/null
iptables -t nat -F

# Redirect HTTP and DNS
iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-ports 8080
iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 53 -j REDIRECT --to-ports 53 2>/dev/null || true

# Start Dnsmasq to handle DNS requests instantly
echo "address=/#/$GW_IP" > /data/data/com.termux/files/home/dnsmasq.conf
dnsmasq -C /data/data/com.termux/files/home/dnsmasq.conf -i "$IFACE" --except-interface=lo > /dev/null 2>&1

echo "[+] Starting PHP Portal Engine..."
$PREFIX/bin/php -S 0.0.0.0:8080 -t /sdcard/termux_portal/ > /dev/null 2>&1 &

echo "[+] Watchdog active and monitoring..."

while true; do
    if ! ip link | grep -q "$IFACE"; then
        echo "[!] Hotspot interface lost. Waiting for reconnection..."
        while [ -z "$(ip link | grep -E -o "$IFACE")" ]; do
            sleep 2
        done
        echo "[+] Interface back. Restoring routing rules..."
        iptables -t nat -F
        iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-ports 8080
        dnsmasq -C /data/data/com.termux/files/home/dnsmasq.conf -i "$IFACE" --except-interface=lo > /dev/null 2>&1
    fi

    if ! pgrep -f "php -S 0.0.0.0:8080" > /dev/null; then
        $PREFIX/bin/php -S 0.0.0.0:8080 -t /sdcard/termux_portal/ > /dev/null 2>&1 &
    fi

    sleep 5
done
