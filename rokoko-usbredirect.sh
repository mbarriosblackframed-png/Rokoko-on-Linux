#!/bin/bash
export LIBVIRT_DEFAULT_URI=qemu:///system

VENDOR="0483"
PRODUCT_SUIT="a432"
PRODUCT_GLOVE="5740"
PORT_SUIT="7700"
PORT_GLOVE="7701"

start_redirect() {
    local PRODUCT=$1
    local PORT=$2
    pkill -f "usbredirect.*$PORT" 2>/dev/null
    while ! lsusb | grep -q "$VENDOR:$PRODUCT"; do :; done
    DEVINFO=$(lsusb | grep "$VENDOR:$PRODUCT")
    BUS=$(echo $DEVINFO | awk '{print $2}')
    DEV=$(echo $DEVINFO | awk '{print $4}' | tr -d :)
    echo "$(date): Conectando $VENDOR:$PRODUCT en ${BUS}-${DEV} -> puerto $PORT" | logger -t rokoko-usb
    usbredirect --device ${BUS}-${DEV} --to 127.0.0.1:$PORT &
}

stop_redirect() {
    local PORT=$1
    echo "$(date): Desconectando puerto $PORT" | logger -t rokoko-usb
    pkill -f "usbredirect.*$PORT" 2>/dev/null
}

SUIT_PATH=""
GLOVE_PATH=""

udevadm monitor --udev --subsystem-match=usb | while read -r line; do
    if echo "$line" | grep -q "bind " && ! echo "$line" | grep -q "unbind"; then
        DEVPATH=$(echo "$line" | awk '{print $4}')
        BUSNUM=$(cat /sys${DEVPATH}/busnum 2>/dev/null)
        DEVNUM=$(cat /sys${DEVPATH}/devnum 2>/dev/null)
        VENDOR_ID=$(cat /sys${DEVPATH}/idVendor 2>/dev/null)
        PRODUCT_ID=$(cat /sys${DEVPATH}/idProduct 2>/dev/null)

        if [ "$VENDOR_ID" = "0483" ] && [ "$PRODUCT_ID" = "$PRODUCT_SUIT" ]; then
            SUIT_PATH="$DEVPATH"
            pkill -f "usbredirect.*$PORT_SUIT" 2>/dev/null
            echo "$(date): Conectando traje ${BUSNUM}-${DEVNUM}" | logger -t rokoko-usb
            usbredirect --device ${BUSNUM}-${DEVNUM} --to 127.0.0.1:$PORT_SUIT &
        elif [ "$VENDOR_ID" = "0483" ] && [ "$PRODUCT_ID" = "$PRODUCT_GLOVE" ]; then
            GLOVE_PATH="$DEVPATH"
            pkill -f "usbredirect.*$PORT_GLOVE" 2>/dev/null
            echo "$(date): Conectando guante ${BUSNUM}-${DEVNUM}" | logger -t rokoko-usb
            usbredirect --device ${BUSNUM}-${DEVNUM} --to 127.0.0.1:$PORT_GLOVE &
        fi
    elif echo "$line" | grep -q "unbind"; then
        DEVPATH=$(echo "$line" | awk '{print $4}')
        if [ "$DEVPATH" = "$SUIT_PATH" ]; then
            SUIT_PATH=""
            stop_redirect $PORT_SUIT
        elif [ "$DEVPATH" = "$GLOVE_PATH" ]; then
            GLOVE_PATH=""
            stop_redirect $PORT_GLOVE
        fi
    fi
done
