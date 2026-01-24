#!/bin/bash

# Test each opentrack plugin to identify which ones fail to load

echo "Testing OpenTrack Plugin Dependencies"
echo "======================================"
echo

PLUGIN_DIR="/opt/opentrack/build/install/libexec/opentrack"

echo "Checking tracker plugins:"
for plugin in $PLUGIN_DIR/opentrack-tracker-*.so; do
    name=$(basename $plugin)
    echo -n "  $name: "
    if ldd $plugin > /dev/null 2>&1; then
        missing=$(ldd $plugin 2>&1 | grep "not found" | wc -l)
        if [ $missing -eq 0 ]; then
            echo "OK"
        else
            echo "MISSING DEPENDENCIES:"
            ldd $plugin 2>&1 | grep "not found"
        fi
    else
        echo "ERROR running ldd"
    fi
done

echo
echo "Checking protocol/output plugins:"
for plugin in $PLUGIN_DIR/opentrack-proto-*.so; do
    name=$(basename $plugin)
    echo -n "  $name: "
    if ldd $plugin > /dev/null 2>&1; then
        missing=$(ldd $plugin 2>&1 | grep "not found" | wc -l)
        if [ $missing -eq 0 ]; then
            echo "OK"
        else
            echo "MISSING DEPENDENCIES:"
            ldd $plugin 2>&1 | grep "not found"
        fi
    else
        echo "ERROR running ldd"
    fi
done

echo
echo "Checking filter plugins:"
for plugin in $PLUGIN_DIR/opentrack-filter-*.so; do
    name=$(basename $plugin)
    echo -n "  $name: "
    if ldd $plugin > /dev/null 2>&1; then
        missing=$(ldd $plugin 2>&1 | grep "not found" | wc -l)
        if [ $missing -eq 0 ]; then
            echo "OK"
        else
            echo "MISSING DEPENDENCIES:"
            ldd $plugin 2>&1 | grep "not found"
        fi
    else
        echo "ERROR running ldd"
    fi
done

echo
echo "Checking video capture plugins:"
for plugin in $PLUGIN_DIR/opentrack-video*.so; do
    name=$(basename $plugin)
    echo -n "  $name: "
    if ldd $plugin > /dev/null 2>&1; then
        missing=$(ldd $plugin 2>&1 | grep "not found" | wc -l)
        if [ $missing -eq 0 ]; then
            echo "OK"
        else
            echo "MISSING DEPENDENCIES:"
            ldd $plugin 2>&1 | grep "not found"
        fi
    else
        echo "ERROR running ldd"
    fi
done

echo
echo "======================================"
echo "Test complete"
