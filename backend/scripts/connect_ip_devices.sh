#!/bin/bash

# ==========================================
# CONFIGURATION
# ==========================================
REACH_TIMEOUT=15
PING_TIMEOUT=1
ADB_PORT=5555

echo
echo "=============================================="
echo "     Connecting To ADB TCP/IP Devices..."
echo "=============================================="
echo

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


# ==========================================
# [C] IF mDNS FAILS → SCAN LOCAL NETWORK
# ==========================================
LAN_DEVICES=""
SCAN_TIMEOUT_PING="0.1"     # 100 ms
SCAN_TIMEOUT_PORT="0.2"     # 200 ms

if [ "$MDNS_FOUND" = false ]; then
    echo
    echo "⚡ mDNS = 0 → Running Ultra-Fast LAN Scan"
    echo "=============================================="
    echo

    LOCAL_IP=$(hostname -I | awk '{print $1}')
    BASE="${LOCAL_IP%.*}"

    echo " • Subnet: $BASE.x"
    echo " • Ping Wait: $SCAN_TIMEOUT_PING sec"
    echo " • Port Timeout: $SCAN_TIMEOUT_PORT sec"
    echo

    TMPFILE=$(mktemp)

    # Allow many parallel sockets
    ulimit -n 4096

    for i in {1..254}; do
        (
            IP="$BASE.$i"

            # ⚡ ultra fast ping (100ms)
            ping -c1 -W$SCAN_TIMEOUT_PING "$IP" >/dev/null 2>&1 || exit

            # ⚡ ultra fast port check (200ms)
            timeout $SCAN_TIMEOUT_PORT bash -c "</dev/tcp/$IP/5555" 2>/dev/null || exit

            echo "$IP:5555" >> "$TMPFILE"
        ) &
    done

    wait

    if [ -s "$TMPFILE" ]; then
        echo "✔ Active ADB devices detected:"
        cat "$TMPFILE"
        echo

        # Connect fast
        while read -r IPPORT; do
            adb connect "$IPPORT" >/dev/null 2>&1 &
        done < "$TMPFILE"

        wait

        LAN_DEVICES=$(cat "$TMPFILE")
    else
        echo "❌ No ADB devices found in scan."
    fi

    rm "$TMPFILE"
fi


# ==========================================
# [D] MERGE mDNS + LAN DISCOVERED DEVICES
# ==========================================
UNIQUE=""

if [ "$MDNS_FOUND" = true ]; then
    UNIQUE=$(echo "$MDNS_RAW" | awk '{print $1, $3}')
fi

if [ -n "$LAN_DEVICES" ]; then
    while read -r IPPORT; do
        [ -z "$IPPORT" ] && continue
        UNIQUE+="LAN_Device $IPPORT"$'\n'
    done <<< "$LAN_DEVICES"
fi

if [ -z "$UNIQUE" ]; then
    echo
    echo "❌ No devices found via mDNS or LAN."
    exit 0
fi


# ==========================================
# DISPLAY UNIQUE DEVICES
# ==========================================
echo
echo "---------------- Unique ADB Devices ----------------"
echo "$UNIQUE" | while read -r NAME IPPORT; do
    printf "Device: %-20s | IP: %s\n" "$NAME" "$IPPORT"
done
echo "---------------------------------------------------"
echo


# ==========================================
# [E] CHECK & CONNECT DEVICES
# ==========================================
echo "Checking device status & connecting..."
echo

echo "$UNIQUE" | while read -r NAME IPPORT; do
    [ -z "$IPPORT" ] && continue

    IP="${IPPORT%:*}"

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