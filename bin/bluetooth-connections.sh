#!/bin/bash

# Script to list Bluetooth adapters and their connected devices

echo "=== Bluetooth Adapters and Connected Devices ==="
echo ""

# Get list of adapters from D-Bus
adapters=$(busctl tree org.bluez | grep -E "^[^│├└─ ]*├─ /org/bluez/hci[0-9]+$|^[^│├└─ ]*└─ /org/bluez/hci[0-9]+$" | sed -E 's/.*\/org\/bluez\/(hci[0-9]+).*/\1/' 2>/dev/null)

if [ -z "$adapters" ]; then
    # Fallback to checking directory listing with glob
    for adapter in /sys/class/bluetooth/hci[0-9]*; do
        [ -e "$adapter" ] && adapters+="$(basename "$adapter") "
    done
fi

# Get the default controller from bluetoothctl
default_controller=$(bluetoothctl list | grep "default" | awk '{print $2}')

# Process each adapter
for hci_dev in $adapters; do
    # Get adapter MAC address using D-Bus
    adapter_mac=$(busctl get-property org.bluez "/org/bluez/$hci_dev" org.bluez.Adapter1 Address 2>/dev/null | cut -d'"' -f2)

    if [ -z "$adapter_mac" ]; then
        continue
    fi

    # Get adapter name
    adapter_name=$(busctl get-property org.bluez "/org/bluez/$hci_dev" org.bluez.Adapter1 Alias 2>/dev/null | cut -d'"' -f2)

    # Check if this is the default adapter
    is_default=""
    if [ "$adapter_mac" == "$default_controller" ]; then
        is_default=" [DEFAULT]"
    fi

    echo "Controller: $adapter_mac ($adapter_name)$is_default"

    # Get all devices under this adapter from D-Bus
    devices=$(busctl tree org.bluez 2>/dev/null | grep -E "(└─|├─) /org/bluez/$hci_dev/dev_[0-9A-F_]+$" | sed -E 's/.*\/dev_([0-9A-F_]+)$/\1/' | sort -u)

    has_connected=false
    connected_devices=""

    for dev in $devices; do
        # Convert underscore format to colon format using parameter expansion
        device_mac="${dev//_/:}"

        # Check if device is connected
        connected=$(busctl get-property org.bluez "/org/bluez/$hci_dev/dev_$dev" org.bluez.Device1 Connected 2>/dev/null | awk '{print $2}')

        if [ "$connected" == "true" ]; then
            has_connected=true

            # Get device name
            device_name=$(busctl get-property org.bluez "/org/bluez/$hci_dev/dev_$dev" org.bluez.Device1 Name 2>/dev/null | cut -d'"' -f2)

            if [ -n "$device_name" ]; then
                connected_devices+="    - $device_mac ($device_name)\n"
            else
                connected_devices+="    - $device_mac\n"
            fi
        fi
    done

    if [ "$has_connected" == true ]; then
        echo "  Connected devices:"
        echo -e "$connected_devices" | grep -v "^$"
    else
        echo "  No connected devices"
    fi

    echo ""
done
