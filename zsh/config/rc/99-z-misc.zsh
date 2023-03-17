alias chatgpt="docker run --rm -it -e TERM='$TERM' -e OPENAI_API_KEY='$OPENAI_API_KEY' four43/chat-gpt-terminator:latest"

function mbtileify() {
    input_file="$1"
    output_file="${input_file%.*}.mbtiles"
    tippecanoe -zg -f -o "$output_file" --drop-densest-as-needed "$input_file"
    du -h "$output_file"
}
