#!/bin/bash

# Start Firefox and open a specific URL
xdg-open 'https://copilot.microsoft.com' &

# Wait for Firefox to start up
sleep 2

# Use xdotool to select the input box and input text
WID=$(xdotool search --onlyvisible --class firefox | head -1)
xdotool windowactivate $WID

# Hit the goto content helper
xdotool key Tab
sleep 0.1
xdotool key Return
sleep 0.01

for i in {1..7}; do
    xdotool key Tab
    sleep 0.01
done

declare -A prompts

prompt_programming="Follow the user's requirements carefuly & to the letter. Keep your answers short and impersonal. Output the code example and only the code xample first, and save all other explantions for the end. Do not give any introduction or preamble before the code example. Be concise with your explanations."

prompts["python"]="You are an AI programming assistant that helps with the Python programming language. $prompt_programming Use python's built in standard libraries as much as possible, but feel free to use popular libraries on pypi."

prompts["bash"]="You are an AI programming assistant that helps with Linux and the Bash/shell programming language. $prompt_programming If in question or not mentioned, the default linux distribution is debian."

prompts["js"]="You are an AI programming assistant that helps with the JavaScript programming language. $prompt_programming Use the latest version of JavaScript (ES2021) and the latest version of Node.js."

active_prompt=${prompts["$1"]}
xdotool type --delay 2 "$active_prompt"
xdotool key 'Shift+Return'
xdotool key 'Shift+Return'

xdotool type --delay 1 "$2"
xdotool key 'Return'
