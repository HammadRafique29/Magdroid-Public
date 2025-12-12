#!/bin/bash

echo
echo "=============================================="
echo "   Assigning TCP/IP to devices without IP..."
echo "=============================================="
echo

echo " • Restarting ADB server to refresh all devices..."
adb kill-server >/dev/null 2>&1
sleep 1
adb start-server >/dev/null 2>&1
sleep 1
echo "   → ADB server restarted successfully."
echo

echo "-------------------------------------"
echo " • Fetching devices..."

# Get all connected ADB devices (USB + TCP)
mapfile -t ADB_DEVICES < <(adb devices | grep -w "device" | awk '{print $1}')
DEVICES=$(adb devices | grep -w "device" | awk '{print $1}')

if [ -z "$DEVICES" ]; then
    echo "No ADB devices found!"
    exit 0
fi


echo "   → Devices found:"
for device in "${ADB_DEVICES[@]}"; do
    echo "     → Device ID: $device";
done
echo "-------------------------------------"

echo

# Loop through each device
echo "$DEVICES" | while read -r DEVICE; do

    # If device name contains an IP address (already TCP/IP), skip it
    if [[ "$DEVICE" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+: ]]; then
        echo " • $DEVICE already has TCP/IP → skipping."
        echo
        continue
    fi

    echo " • $DEVICE → No IP assigned"
    echo "     → Enabling TCP/IP on port 5555..."

    adb -s "$DEVICE" tcpip 5555 >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo "     → TCP/IP enabled successfully ✔"
    else
        echo "     → Failed to enable TCP/IP ✖"
    fi

    echo
done

echo "=============================================="
echo "   Completed assigning TCP/IP."
echo "=============================================="