#!/bin/bash

# Sets up our "pinned" workspaces and what monitor they should go to.
# I3_WS and I3_WS_MONITORS should be "zipped" together if we need them.
export I3_WS="terminal browser"

DISPLAYS=($(echo $DISPLAY_ORDER))
export I3_WS_DISPLAYS="${DISPLAYS[2]} ${DISPLAYS[1]}"
