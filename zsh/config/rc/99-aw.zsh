#!/usr/bin/zsh

export PATH="${PATH}:$HOME/projects/aerisweather/devtools/aws"
alias vpn-up="TMUX_WINDOW_PREV_NAME=\"\$(tmux display-message -p '#W')\"; tmux rename-window '旅AW-VPN'; sudo ~/projects/aerisweather/infra-mgmt/util/vpn/openvpn-connect ~/Documents/AerisWeather/smiller.conf; tmux rename-window \$TMUX_WINDOW_PREV_NAME"
alias project-coverage-open="xdg-open ./.tests-output/test-results/html/index.html"

alias tmp-chown="sudo chown -R smiller:admin /tmp/*std* /tmp/*raw* /tmp/funnel*"

alias devops-container='docker run --rm -it -e AWS_PROFILE=aerisweather -v ~/.aws:/root/.aws -v "$PWD:$PWD" -v /var/run/docker.sock:/var/run/docker.sock -w "$PWD" aerisweather/cicd-basics:6 /bin/bash'
alias amp-refresh-asg='docker run --rm -it -e AWS_PROFILE=aerisweather -v ~/.aws:/root/.aws -v "$PWD:$PWD" -v /var/run/docker.sock:/var/run/docker.sock -w "$PWD" aerisweather/cicd-basics:6 /scripts/ec2-refresh.py refresh "$(aws-ec2-asg-ls amp-)"'

function goes-updated-times() {
    sats=("goes16" "goes17" "goes18")
    for sat in "${sats[@]}"; do
        year="$(aws s3 ls "s3://noaa-${sat}/ABI-L2-CMIPF/" | tail -n 1 | awk '{print $2}' | grep -o -E '[0-9]+')"
        day="$(aws s3 ls "s3://noaa-${sat}/ABI-L2-CMIPF/${year}/" | tail -n 1 | awk '{print $2}' | grep -o -E '[0-9]+')"
        hour="$(aws s3 ls "s3://noaa-${sat}/ABI-L2-CMIPF/${year}/${day}/" | tail -n 1 | awk '{print $2}' | grep -o -E '[0-9]+')"
        file_list="$(aws s3 ls "s3://noaa-${sat}/ABI-L2-CMIPF/${year}/${day}/${hour}/" | tail -n 1)"
        echo "s3://noaa-${sat}/ABI-L2-CMIPF/${year}/${day}/${hour}/" >&2
        if [[ "$?" != "0" ]]; then
            hour=$((hour - 1))
            file_list="$(aws s3 ls "s3://noaa-${sat}/ABI-L2-CMIPF/${year}/${day}/${hour}/" | tail -n 1)"
        fi
        echo "$sat updated at $(echo "$file_list" | sed -E 's/.*c([0-9]{4})([0-9]{3})([0-9]{2})([0-9]{2})([0-9]{2}).*/\1 d\2 @ \3:\4:\5Z/')"
    done
}

function aeris-api-query-all() {
    endpoint="$1"
    filter_extras="$2"

    page="1"
    page_size="1000"

    tmp_dir=$(mktemp -d -t "$(basename "$0")-XXX")
    # trap 'rm -rf ${tmp_dir}' EXIT
    echo "tmp_dir: ${tmp_dir}" >&2
    while true; do
        skip=$(((page - 1) * page_size))
        output_file="${tmp_dir}/output.${page}.geojson"
        echo "Querying page ${page}..." >&2
        url="https://api.aerisapi.com/${endpoint}/search?limit=${page_size}&skip=${skip}&filter=geo,${filter_extras}&format=geojson&client_id=${AERIS_CLIENT_ID}&client_secret=${AERIS_CLIENT_SECRET}"
        if [[ $page == "1" ]]; then
            echo "$url" >&2
        fi
        curl -s "$url" >"${output_file}"
        records="$(cat "${output_file}" | jq -r '.features | length')"
        if [[ "$records" -gt "0" ]]; then
            page=$((page + 1))
        else
            rm -rf "${output_file}"
            break
        fi
    done
    echo "Saving data to ${endpoint}.geojson" >&2
    jq_query=$(
        cat <<-EOM
    {
        "type": "FeatureCollection",
        "features": [.[] | .features[] | {
            "id": .id,
            "type": .type,
            "geometry": .geometry,
            "properties": .properties | [leaf_paths as \$path | {"key": \$path | join("."), "value": getpath(\$path)}] | from_entries }
        ]
    }
EOM
    )
    jq "$jq_query" --slurp "${tmp_dir}"/*.geojson >"$endpoint".geojson
}

function xwx-jira-projects () {

    xdg-open 'https://medialogicgroup.atlassian.net/jira/software/c/projects/FNNL/issues/?filter=allissues&jql=ORDER%20BY%20created%20DESC'
    xdg-open 'https://medialogicgroup.atlassian.net/jira/software/c/projects/FNNL/boards/61/timeline'
    xdg-open 'https://medialogicgroup.atlassian.net/jira/software/c/projects/AERISAPI/boards/74/timeline'
    xdg-open 'https://medialogicgroup.atlassian.net/jira/software/c/projects/MAPSGLAPI/boards/63/timeline'
}
