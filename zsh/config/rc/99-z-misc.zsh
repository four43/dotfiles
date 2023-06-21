alias chatgpt="docker run --rm -it -e TERM='$TERM' -e OPENAI_API_KEY='$OPENAI_API_KEY' four43/chat-gpt-terminator:latest"

function mbtileify() {
    input_file="$1"
    output_file="${input_file%.*}.mbtiles"
    set -x
    tippecanoe -f -o "$output_file" ${@:2} \
      -z0 -z12 \
      "$input_file"
    set +x
    du -h "$output_file"
}
