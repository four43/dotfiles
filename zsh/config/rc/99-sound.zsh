#!/bin/zsh

# Bluetooth Audio Devices
export BT_BOSE_QC35_MAC="4C:87:5D:77:80:78"
export BT_APPLE_AIRPOD_PRO_MAC="A8:51:AB:DA:31:F0"

function sound-set-output() {
    set -o pipefail

    local sink_query=""
    if [[ -n "$1" ]]; then
        sink_query="$1"
    elif [ ! -t 0 ]; then
        sink_query="$(cat)"
    else
        sink_query=$(pactl list short sinks | awk '{ print $2 }' | fzf)
    fi
    if [[ $? -ne 0 ]]; then
        # Quit in fzf menu
        return
    fi
    sink_id=$(pactl list short sinks | grep -e "$sink_query" | awk '{ print $1 }')
    sink_name=$(pactl list short sinks | grep -e "$sink_query" | awk '{ print $2 }')
    if [[ $? -ne 0 ]]; then
        echo "Couldn't find output sink by name of: ${sink_query}" >&2
        return 1
    fi
    echo "Chose ${sink_name} with id of ${sink_id}" >&2

    pactl set-default-sink "$sink_name"
    pactl list short sink-inputs | awk '{ print $1 }' | xargs -n 1 -I % pactl move-sink-input % "$sink_id"
}

bluetooth_card="bluez_card.4C_87_5D_77_80_78"
function sound-mic-up() {
    pactl set-card-profile "$bluetooth_card" headset_head_unit
}

function sound-mic-down() {
    pactl set-card-profile "$bluetooth_card" a2dp_sink
}

function headphones-up() {
    device="$(printenv | grep '^BT_' | sed -E 's/^BT_(.+)_MAC=(.+)$/\1 \2/' | fzf)"
    device_name="$(echo "$device" | awk '{ print $1 }')"
    device_mac="$(echo "$device" | awk '{ print $2 }')"
    echo "Connecting to ${device_name} BT MAC: $device_mac" >&2
    echo '!!! Put headphones in pairing mode !!!' >&2
    sudo rfkill unblock bluetooth
    bluetoothctl agent on
    sleep 3
    bluetoothctl remove $device_mac
    timeout 3s bluetoothctl scan on
    bluetoothctl trust $device_mac
    bluetoothctl pair $device_mac
    bluetoothctl connect $device_mac
}

function headphones-down() {
    sudo rfkill block bluetooth
}
