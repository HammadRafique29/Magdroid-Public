#!/bin/bash

# Read the device IP range from environment variable, with a default value.
DEVICES_RANGE="${DEVICES_RANGE:-192.168.1.0/24}"

echo
echo "=============================================="
echo "   Assigning TCP/IP to devices without IP..."
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
        device_ip="${DEVICE%:*}"
        if ! is_ip_in_range "$device_ip"; then
            echo " • WARNING: $DEVICE is connected but outside the allowed IP range."
        else
            echo " • $DEVICE already has TCP/IP and is in range → skipping."
        fi
        echo
        continue
    fi

    echo " • $DEVICE → No IP assigned"
    echo "     → Enabling TCP/IP on port 5555..."

    adb -s "$DEVICE" tcpip 5555 >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo "     → TCP/IP enabled successfully ✔"
        
        # After enabling TCP/IP, we need to find out the device's IP to validate it.
        # This is tricky as the IP is not known at this stage.
        # The validation will primarily be enforced by `connect_ip_devices.sh`.
        # We can add a note here.
        echo "     → NOTE: IP address will be validated upon connection."

    else
        echo "     → Failed to enable TCP/IP ✖"
    fi

    echo
done

echo "=============================================="
echo "   Completed assigning TCP/IP."
echo "=============================================="