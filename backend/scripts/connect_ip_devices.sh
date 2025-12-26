#!/bin/bash

# ==========================================
# CONFIGURATION
# ==========================================
REACH_TIMEOUT=15
PING_TIMEOUT=1
ADB_PORT=5555

# Read the device IP range from environment variable, with a default value.
DEVICES_RANGE="${DEVICES_RANGE:-192.168.1.0/24}"

echo
echo "=============================================="
echo "     Connecting To ADB TCP/IP Devices"
echo "=============================================="
echo "Using IP Range: $DEVICES_RANGE"
echo

# Convert IP address to an integer for comparison.
ip_to_int() {
    local a b c d
    IFS=. read -r a b c d <<<"$1"
    echo "$(( (a << 24) | (b << 16) | (c << 8) | d ))"
}

# Check if a given IP is within any of the specified ranges.
is_ip_in_range() {
    local ip_to_check_int
    ip_to_check_int=$(ip_to_int "$1")
    
    # Use standard IFS for splitting.
    local OLD_IFS="$IFS"
    IFS=','
    
    for range in $DEVICES_RANGE; do
        # Restore IFS if needed inside the loop, though we mostly use pattern matching.
        IFS="$OLD_IFS"

        # CIDR format: 192.168.1.0/24
        if [[ "$range" == *"/"* ]]; then
            # Use ipcalc to check if the IP is in the subnet.
            if ipcalc -c -n "$range" "$1" &>/dev/null; then
                return 0 # IP is in the range.
            fi

        # Range format: 192.168.1.40-192.168.1.45
        elif [[ "$range" == *"-"* ]]; then
            local start_ip end_ip
            start_ip="${range%-*}"
            end_ip="${range#*-}"
            
            local start_ip_int end_ip_int
            start_ip_int=$(ip_to_int "$start_ip")
            end_ip_int=$(ip_to_int "$end_ip")
            
            if [[ "$ip_to_check_int" -ge "$start_ip_int" ]] && [[ "$ip_to_check_int" -le "$end_ip_int" ]]; then
                return 0 # IP is in the range.
            fi

        # Single IP format: 192.168.2.100
        else
            if [[ "$1" == "$range" ]]; then
                return 0 # IP matches.
            fi
        fi

        # Reset IFS for the next iteration of the loop.
        IFS=","
    done
    
    # Restore original IFS after loop.
    IFS="$OLD_IFS"
    
    return 1 # IP is not in any of the ranges.
}

echo " • Restarting ADB server..."
adb kill-server >/dev/null 2>&1
sleep 1
adb start-server >/dev/null 2>&1
sleep 1
echo "   → ADB restarted."
echo


# ==========================================
# [A] GET CONNECTED DEVICES (USB + TCP)
# ==========================================
ADB_CONNECTED=$(adb devices | grep -w "device" | awk '{print $1}')
echo "$ADB_CONNECTED"

# ==========================================
# [B] DISCOVER DEVICES VIA mDNS
# ==========================================
echo " • Scanning ADB mDNS services..."
MDNS_RAW=$(adb mdns services | grep "_adb._tcp")

if [ -z "$MDNS_RAW" ]; then
    echo "   → No mDNS devices found!"
    MDNS_FOUND=false
else
    MDNS_FOUND=true
fi

echo "$MDNS_FOUND"

# ==========================================
# [C] SCAN LOCAL NETWORK
# ==========================================
LAN_DEVICES=""
SCAN_TIMEOUT_PING="0.1"     # 100 ms
SCAN_TIMEOUT_PORT="0.2"     # 200 ms

echo
echo "⚡ Running Ultra-Fast LAN Scan"
echo "=============================================="
echo

# Create temporary file for results
TMPFILE=$(mktemp)

# Allow many parallel sockets
ulimit -n 4096

# Helper: iterate over DEVICE_RANGE (supports CIDR or dash ranges)
iterate_ip_range() {
    local range="$1"

    if [[ "$range" == *"/"* ]]; then
        # CIDR range → use 'prips' or 'ipcalc -n'
        # Fallback to seq on last octet
        BASE="${range%.*}.0"
        START=1
        END=254
        for i in $(seq $START $END); do
            echo "${BASE%0}$i"
        done
    elif [[ "$range" == *"-"* ]]; then
        # Dash range: 192.168.1.40-192.168.1.45
        local start_ip="${range%-*}"
        local end_ip="${range#*-}"

        local start_int end_int
        start_int=$(ip_to_int "$start_ip")
        end_int=$(ip_to_int "$end_ip")

        for ((ip=start_int; ip<=end_int; ip++)); do
            echo "$(int_to_ip "$ip")"
        done
    else
        # Single IP
        echo "$range"
    fi
}

# Helper: convert int → IP
int_to_ip() {
    local ip=$1
    echo "$(( (ip >> 24) & 255 )).$(( (ip >> 16) & 255 )).$(( (ip >> 8) & 255 )).$((ip & 255))"
}

# Iterate through DEVICE_RANGE and scan each IP
for range in ${DEVICE_RANGE//,/ }; do
    while read -r IP; do
        (
            # ⚡ ultra fast ping
            ping -c1 -W$SCAN_TIMEOUT_PING "$IP" >/dev/null 2>&1 || exit

            # ⚡ ultra fast ADB port check
            timeout $SCAN_TIMEOUT_PORT bash -c "</dev/tcp/$IP/5555" 2>/dev/null || exit

            # Only write authorized IPs
            echo "$IP:5555" >> "$TMPFILE"
        ) &
    done < <(iterate_ip_range "$range")
done

# Wait for all background jobs
wait

if [ -s "$TMPFILE" ]; then
    echo "✔ Active & authorized ADB devices detected:"
    sort -u "$TMPFILE"
    echo

    # Connect fast
    while read -r IPPORT; do
        adb connect "$IPPORT" >/dev/null 2>&1 &
    done < "$TMPFILE"

    wait

    LAN_DEVICES=$(cat "$TMPFILE")
else
    echo "❌ No authorized ADB devices found in scan."
fi

rm "$TMPFILE"


# ==========================================
# [D] MERGE mDNS + LAN DISCOVERED DEVICES
# ==========================================
UNIQUE=""

if [ "$MDNS_FOUND" = true ]; then
    # Filter mDNS results here, before they are added to the UNIQUE list
    while read -r name ipport; do
        ip="${ipport%:*}"
        if is_ip_in_range "$ip"; then
            UNIQUE+="$name $ipport"$'\n'
        fi
    done <<< "$(echo "$MDNS_RAW" | awk '{print $1, $3}')"
fi
# echo "$UNIQUE"

if [ -n "$LAN_DEVICES" ]; then
    # The LAN_DEVICES list is already pre-filtered, so we can add it directly.
    while read -r IPPORT; do
        [ -z "$IPPORT" ] && continue
        # The device name is arbitrary for LAN scans, so "LAN_Device" is fine.
        UNIQUE+="LAN_Device $IPPORT"$'\n'
    done <<< "$LAN_DEVICES"
fi
# echo "$LAN_DEVICES"

if [ -z "$UNIQUE" ]; then
    echo
    echo "❌ No devices found via mDNS or LAN."
    exit 0
fi

# ==========================================
# [D.1] FILTER DEVICES BY IP RANGE
# ==========================================
FILTERED_UNIQUE=""

while read -r NAME IPPORT; do
    [ -z "$IPPORT" ] && continue

    IP="${IPPORT%:*}"

    if is_ip_in_range "$IP"; then
        FILTERED_UNIQUE+="$NAME $IPPORT"$'\n'
    fi
done < <(echo "$UNIQUE")

echo "$FILTERED_UNIQUE"


# Replace UNIQUE with the filtered list
UNIQUE="$FILTERED_UNIQUE"

if [ -z "$UNIQUE" ]; then
    echo
    echo "❌ No devices found within the authorized IP range ($DEVICES_RANGE)."
    exit 0
fi


# ==========================================
# DISPLAY UNIQUE DEVICES
# ==========================================

# Re-filter the merged list to be absolutely sure no unauthorized devices slip through.
FILTERED_UNIQUE=""

while read -r NAME IPPORT; do
    [ -z "$IPPORT" ] && continue
    IP="${IPPORT%:*}"

    if is_ip_in_range "$IP"; then
        FILTERED_UNIQUE+="$NAME $IPPORT"$'\n'
    fi
done <<< "$UNIQUE"

UNIQUE="$FILTERED_UNIQUE"
# echo "$UNIQUE"

if [ -z "$UNIQUE" ]; then
    echo
    echo "❌ No devices found within the authorized IP range ($DEVICES_RANGE)."
    exit 0
fi


echo
echo "---------------- Unique ADB Devices ----------------"
echo "$UNIQUE"

while read -r NAME IPPORT; do
    printf "Device: %-20s | IP: %s\n" "$NAME" "$IPPORT"
done <<< "$UNIQUE"

echo "---------------------------------------------------"


# ==========================================
# [E] CHECK & CONNECT DEVICES
# ==========================================
echo "Checking device status & connecting..."
echo

echo "$UNIQUE" | while read -r NAME IPPORT; do
    [ -z "$IPPORT" ] && continue

    IP="${IPPORT%:*}"

    # Validate IP before attempting any connection.
    if ! is_ip_in_range "$IP"; then
        echo "Skipping device $IP (not in authorized range)"
        continue
    fi
    
    # Already connected?
    if adb devices | grep -q "$IPPORT"; then
        echo " • $IPPORT already connected → checking..."
        ping -c1 -W"$PING_TIMEOUT" "$IP" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "    ✔ Reachable"
        else
            echo "    ✖ Not reachable → reconnecting..."
            adb connect "$IPPORT" >/dev/null 2>&1
        fi
        echo
        continue
    fi

    # Not connected → connect
    echo " • Connecting to $IPPORT ..."
    adb connect "$IPPORT" >/dev/null 2>&1
    sleep 1

    ping -c1 -W"$PING_TIMEOUT" "$IP" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "    ✔ Connected OK"
    else
        echo "    ✖ Connection failed"
    fi
    echo

done


# ==========================================
# [F] HEALTH CHECK LOOP (DISCONNECT ONLY IP)
# ==========================================
echo
echo "====================================================="
echo "  Starting Health Checks (every $REACH_TIMEOUT sec)"
echo "====================================================="
echo

echo "[Health Check] $(date '+%Y-%m-%d %H:%M:%S')"
echo

echo "$UNIQUE" | while read -r NAME IPPORT; do
    [ -z "$IPPORT" ] && continue

    IP="${IPPORT%:*}"

    printf " • Checking %s (%s)... " "$NAME" "$IP"

    # Also check range for health checks.
    if ! is_ip_in_range "$IP"; then
        echo "Skipped_unauthorized_device: $IP (Health Check)"
        continue
    fi

    ping -c1 -W"$PING_TIMEOUT" "$IP" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Reachable ✔"
    else
        echo "NOT Reachable ✖"
        echo "     → Trying reconnect..."
        adb connect "$IPPORT" >/dev/null 2>&1
    fi
done

echo


# #!/bin/bash

# # ================================
# #  CONFIGURATION
# # ================================
# REACH_TIMEOUT=15     # seconds between each full health check
# PING_TIMEOUT=1       # 1 second reach test per device
# # ================================

# echo
# echo "=============================================="
# echo "       Connecting To ADB IP Devices..."
# echo "=============================================="
# echo

# echo " • Restarting ADB server to refresh all devices..."
# adb kill-server >/dev/null 2>&1
# sleep 1
# adb start-server >/dev/null 2>&1
# sleep 1
# echo "   → ADB server restarted successfully."


# # while true; do

# # echo "-------------------------------------"
# # echo " • Fetching devices..."

# # # Get all connected ADB devices (USB + TCP)
# # mapfile -t ADB_DEVICES < <(adb devices | grep -w "device" | awk '{print $1}')
# # DEVICES=$(adb devices | grep -w "device" | awk '{print $1}')

# # # if [ -z "$DEVICES" ]; then
# #     # echo "No ADB devices found!"
# # # fi

# # if [ -n "$DEVICES" ]; then
# #     echo "   → Devices found:"

# #     for device in "${ADB_DEVICES[@]}"; do
# #         echo "     → Device ID: $device";
# #     done
# #     echo "-------------------------------------"
# #     echo

# #     # Loop through each device
# #     echo "$DEVICES" | while read -r DEVICE; do

# #         # If device name contains an IP address (already TCP/IP), skip it
# #         if [[ "$DEVICE" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+: ]]; then
# #             echo " • $DEVICE already has TCP/IP → skipping."
# #             echo
# #             continue
# #         fi

# #         echo " • $DEVICE → No IP assigned"
# #         echo "     → Enabling TCP/IP on port 5555..."

# #         adb -s "$DEVICE" tcpip 5555 >/dev/null 2>&1

# #         if [ $? -eq 0 ]; then
# #             echo "     → TCP/IP enabled successfully ✔"
# #         else
# #             echo "     → Failed to enable TCP/IP ✖"
# #         fi

# #         echo
# #     done
# # fi




# # echo "=============================================="
# # echo "   Completed assigning TCP/IP."
# # echo "=============================================="


# # ------------------------------------------
# #   [1]   Getting connected ADB devices...
# # ------------------------------------------
# ADB_CONNECTED=$(adb devices | grep -w "device" | awk '{print $1}')

# # ------------------------------------------
# #   [2]   Fetching ADB mDNS services...
# # ------------------------------------------
# MDNS_RAW=$(adb mdns services | grep "_adb._tcp")

# if [ -z "$MDNS_RAW" ]; then
#     echo
#     echo "   No devices detected via mDNS!"
#     echo "   Waiting $REACH_TIMEOUT seconds..."
#     echo "   -----------------------------------------------------"
#     sleep "$REACH_TIMEOUT"
#     # continue
# fi

# # ------------------------------------------
# #   [3]   Extracting unique devices...
# # ------------------------------------------
# UNIQUE=$(echo "$MDNS_RAW" | awk '{print $1, $3}' | sort -u -k2)

# echo
# echo "---------------- Unique ADB Devices ----------------"
# echo "$UNIQUE" | while read -r NAME IPPORT; do
#     printf "Device: %-22s  IP: %s\n" "$NAME" "$IPPORT"
# done
# echo "---------------------------------------------------"
# echo

# # ------------------------------------------
# #   [4]   Initial connection check & repair...
# # ------------------------------------------
# echo "Checking device reachability and reconnecting if needed..."
# echo

# echo "$UNIQUE" | while read -r NAME IPPORT; do
#     IP="${IPPORT%:*}"

#     ALREADY=$(adb devices | grep "$IPPORT")

#     if [ -n "$ALREADY" ]; then
#         echo " • $NAME already connected → checking reachability ($IP)..."

#         ping -c1 -W"$PING_TIMEOUT" "$IP" >/dev/null 2>&1
#         if [ $? -eq 0 ]; then
#             echo "     → Reachable. Skipping."
#             echo
#             continue
#         fi

#         echo "     → Not reachable — trying reconnect..."
#         adb connect "$IPPORT" >/dev/null 2>&1
#         sleep 1

#         ping -c1 -W"$PING_TIMEOUT" "$IP" >/dev/null 2>&1
#         if [ $? -eq 0 ]; then
#             echo "     → Reconnected successfully!"
#         else
#             echo "     → Failed reconnect — disconnecting..."
#             adb disconnect "$IPPORT" >/dev/null 2>&1
#         fi
        
#         echo
#         continue
#     fi

#     echo " • $NAME not connected → connecting..."
#     adb connect "$IPPORT" >/dev/null 2>&1
#     sleep 1

#     ping -c1 -W"$PING_TIMEOUT" "$IP" >/dev/null 2>&1
#     if [ $? -eq 0 ]; then
#         echo "     → Connected successfully!"
#     else
#         echo "     → Failed, ignoring."
#     fi

#     echo

# done

# # ------------------------------------------
# #   [5]   HEALTH-CHECK LOOP (IP-only disconnect)
# # ------------------------------------------
# echo
# echo "====================================================="
# echo "   Starting continuous health check every $REACH_TIMEOUT seconds..."
# echo "   Press CTRL+C to stop."
# echo "====================================================="
# echo

# # while true; do
# echo "[Health Check] $(date '+%Y-%m-%d %H:%M:%S')"
# echo

# echo "$UNIQUE" | while read -r NAME IPPORT; do
#     IP="${IPPORT%:*}"

#     printf " • Checking %-20s (%s) ... " "$NAME" "$IP"

#     ping -c1 -W"$PING_TIMEOUT" "$IP" >/dev/null 2>&1
#     if [ $? -eq 0 ]; then
#         echo "Reachable ✔"
#     else
#         echo "NOT Reachable ✖"

#         # Only disconnect if device has an IP (TCP/IP)
#         if [[ "$IPPORT" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+: ]]; then
#             echo "     → Trying reconnect..."
#             adb connect "$IPPORT" >/dev/null 2>&1
#             sleep 1

#             ping -c1 -W"$PING_TIMEOUT" "$IP" >/dev/null 2>&1
#             if [ $? -eq 0 ]; then
#                 echo "     → Reconnected successfully ✔"
#             else
#                 echo "     → Reconnect failed — disconnecting..."
#                 adb disconnect "$IPPORT" >/dev/null 2>&1
#             fi
#         else
#             # Device without IP → never disconnect
#             echo "     → Device has no IP (USB-only) → skipping disconnect."
#         fi
#     fi
#     # echo
# done

# # echo
# # echo "Waiting $REACH_TIMEOUT seconds..."
# # echo "-----------------------------------------------------"
# # sleep "$REACH_TIMEOUT"

# # done


# # #!/bin/bash

# # # ================================
# # #  CONFIGURATION
# # # ================================
# # REACH_TIMEOUT=15     # seconds between each full health check
# # PING_TIMEOUT=1       # 1 second reach test per device
# # # ================================

# # echo
# # echo "=============================================="
# # echo "       Connecting To ADB IP Devices..."
# # echo "=============================================="
# # echo

# # echo " • Restarting ADB server to refresh all devices..."
# # adb kill-server >/dev/null 2>&1
# # sleep 1
# # adb start-server >/dev/null 2>&1
# # sleep 1
# # echo "   → ADB server restarted successfully."


# # # while true; do

# # # echo "-------------------------------------"
# # # echo " • Fetching devices..."

# # # # Get all connected ADB devices (USB + TCP)
# # # mapfile -t ADB_DEVICES < <(adb devices | grep -w "device" | awk '{print $1}')
# # # DEVICES=$(adb devices | grep -w "device" | awk '{print $1}')

# # # # if [ -z "$DEVICES" ]; then
# # #     # echo "No ADB devices found!"
# # # # fi

# # # if [ -n "$DEVICES" ]; then
# # #     echo "   → Devices found:"

# # #     for device in "${ADB_DEVICES[@]}"; do
# # #         echo "     → Device ID: $device";
# # #     done
# # #     echo "-------------------------------------"
# # #     echo

# # #     # Loop through each device
# # #     echo "$DEVICES" | while read -r DEVICE; do

# # #         # If device name contains an IP address (already TCP/IP), skip it
# # #         if [[ "$DEVICE" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+: ]]; then
# # #             echo " • $DEVICE already has TCP/IP → skipping."
# # #             echo
# # #             continue
# # #         fi

# # #         echo " • $DEVICE → No IP assigned"
# # #         echo "     → Enabling TCP/IP on port 5555..."

# # #         adb -s "$DEVICE" tcpip 5555 >/dev/null 2>&1

# # #         if [ $? -eq 0 ]; then
# # #             echo "     → TCP/IP enabled successfully ✔"
# # #         else
# # #             echo "     → Failed to enable TCP/IP ✖"
# # #         fi

# # #         echo

# # #     done
# # # fi




# # # echo "=============================================="
# # # echo "   Completed assigning TCP/IP."
# # # echo "=============================================="


# # # ------------------------------------------
# # #   [1]   Getting connected ADB devices...
# # # ------------------------------------------
# # ADB_CONNECTED=$(adb devices | grep -w "device" | awk '{print $1}')

# # # ------------------------------------------
# # #   [2]   Fetching ADB mDNS services...
# # # ------------------------------------------
# # MDNS_RAW=$(adb mdns services | grep "_adb._tcp")

# # if [ -z "$MDNS_RAW" ]; then
# #     echo "   No devices detected via mDNS!"
# #     echo "   Waiting $REACH_TIMEOUT seconds..."
# #     echo "   -----------------------------------------------------"
# #     sleep "$REACH_TIMEOUT"
# #     continue
# # fi

# # # ------------------------------------------
# # #   [3]   Extracting unique devices...
# # # ------------------------------------------
# # UNIQUE=$(echo "$MDNS_RAW" | awk '{print $1, $3}' | sort -u -k2)

# # echo
# # echo "---------------- Unique ADB Devices ----------------"
# # echo "$UNIQUE" | while read -r NAME IPPORT; do
# #     printf "Device: %-22s  IP: %s\n" "$NAME" "$IPPORT"
# # done
# # echo "---------------------------------------------------"
# # echo

# # # ------------------------------------------
# # #   [4]   Initial connection check & repair...
# # # ------------------------------------------
# # echo "Checking device reachability and reconnecting if needed..."
# # echo

# # echo "$UNIQUE" | while read -r NAME IPPORT; do
# #     IP="${IPPORT%:*}"

# #     ALREADY=$(adb devices | grep "$IPPORT")

# #     if [ -n "$ALREADY" ]; then
# #         echo " • $NAME already connected → checking reachability ($IP)..."

# #         ping -c1 -W"$PING_TIMEOUT" "$IP" >/dev/null 2>&1
# #         if [ $? -eq 0 ]; then
# #             echo "     → Reachable. Skipping."
# #             echo
# #             continue
# #         fi

# #         echo "     → Not reachable — trying reconnect..."
# #         adb connect "$IPPORT" >/dev/null 2>&1
# #         sleep 1

# #         ping -c1 -W"$PING_TIMEOUT" "$IP" >/dev/null 2>&1
# #         if [ $? -eq 0 ]; then
# #             echo "     → Reconnected successfully!"
# #         else
# #             echo "     → Failed reconnect — disconnecting..."
# #             adb disconnect "$IPPORT" >/dev/null 2>&1
# #         fi
        
# #         echo
# #         continue
# #     fi

# #     echo " • $NAME not connected → connecting..."
# #     adb connect "$IPPORT" >/dev/null 2>&1
# #     sleep 1

# #     ping -c1 -W"$PING_TIMEOUT" "$IP" >/dev/null 2>&1
# #     if [ $? -eq 0 ]; then
# #         echo "     → Connected successfully!"
# #     else
# #         echo "     → Failed, ignoring."
# #     fi

# #     echo

# # done

# # # ------------------------------------------
# # #   [5]   HEALTH-CHECK LOOP (IP-only disconnect)
# # # ------------------------------------------
# # echo
# # echo "====================================================="
# # echo "   Starting continuous health check every $REACH_TIMEOUT seconds..."
# # echo "   Press CTRL+C to stop."
# # echo "====================================================="
# # echo

# # # while true; do
# # echo "[Health Check] $(date '+%Y-%m-%d %H:%M:%S')"
# # echo

# # echo "$UNIQUE" | while read -r NAME IPPORT; do
# #     IP="${IPPORT%:*}"

# #     printf " • Checking %-20s (%s) ... " "$NAME" "$IP"

# #     ping -c1 -W"$PING_TIMEOUT" "$IP" >/dev/null 2>&1
# #     if [ $? -eq 0 ]; then
# #         echo "Reachable ✔"
# #     else
# #         echo "NOT Reachable ✖"

# #         # Only disconnect if device has an IP (TCP/IP)
# #         if [[ "$IPPORT" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+: ]]; then
# #             echo "     → Trying reconnect..."
# #             adb connect "$IPPORT" >/dev/null 2>&1
# #             sleep 1

# #             ping -c1 -W"$PING_TIMEOUT" "$IP" >/dev/null 2>&1
# #             if [ $? -eq 0 ]; then
# #                 echo "     → Reconnected successfully ✔"
# #             else
# #                 echo "     → Reconnect failed — disconnecting..."
# #                 adb disconnect "$IPPORT" >/dev/null 2>&1
# #             fi
# #         else
# #             # Device without IP → never disconnect
# #             echo "     → Device has no IP (USB-only) → skipping disconnect."
# #         fi
# #     fi
# #     # echo

# # done

# # # echo
# # # echo "Waiting $REACH_TIMEOUT seconds..."
# # # echo "-----------------------------------------------------"
# # # sleep "$REACH_TIMEOUT"

# # # done