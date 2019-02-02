#!/usr/bin/env bash
set -e

for filename in ${DOTFILE_DIR}/themes/current/init.d/*.sh; do
    [ -e "$filename" ] || continue
    $filename
done
