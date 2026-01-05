IFACE=$(/usr/bin/ip link show | grep tun0 | awk '{print $2}' | tr -d ':')
 
if [ "$IFACE" = "tun0" ]; then
    echo "%{F#1bbf3e}󰖂 %{F#ffffff}$(/usr/bin/ip a show tun0 | grep "inet " | awk '{print $2}' | awk -F/ '{print $1}')%{u-}"
else
    echo "%{F#1bbf3e}󰖂 %{u-} Disconnected"
fi
