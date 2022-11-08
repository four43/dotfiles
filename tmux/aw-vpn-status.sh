#!/bin/bash

if dig -t TXT +short vpc.aerisframework.com | grep -q 'Intranet' ; then
    echo "AW VPN "
else
    echo ""
fi
