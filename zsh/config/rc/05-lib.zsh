function log-debug() {
    if [[ -n "$LOG_DEBUG" ]]; then
        echo "$@" >&2
    fi
}

function pathmunge() {
    if ! echo $PATH | grep -E -q "(^|:)$1($|:)"; then
        if [ "$2" = "after" ]; then
            PATH=$PATH:$1
        else
            PATH=$1:$PATH
        fi
    fi
}

function pathmunge_reorder() {
    PATH="$(echo "$PATH" | sed -E -e "s#(^|:)$1($|:)#:#" | sed -E -e 's/(^:|:$)//')"
    pathmunge "$@"
}

function confirm-cmd() {
    cmd="$@"

    # echo "Command: ${cmd}" >&2 # Debug info
    read -q "REPLY?Are you sure [Yy]? "
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi

    "$@"
}

function columns() {
    # Use printf for better portability: https://stackoverflow.com/a/525873/387851
    tab=$(printf '\t')
    cat - | column -t -s "$tab"
}

# Filters output via fzf if interactive (or if force_interactive is set to 1).
# Pass a search term as first arg, only output first column if arg2 is true
function search-output() {
    log-debug "Searching for ${search_term}, $force_interactive" >&2
    local search_term="$1"
    local only_first_flag="$2"
    local data=$(cat)

    function output_filter_only_first() {
        if [[ -n "$only_first_flag" ]]; then
            cat | awk '{print $1}'
        else
            cat
        fi
    }

    # Short circuit, matched one perfectly
    match_results="$(echo -e "$data" | grep -E "${search_term}")"
    log-debug "Match results = $match_results" >&2
    if [[ $(echo "$match_results" | wc -l) == 1 ]]; then
        echo -e "$data" |
            grep -E "${search_term}" |
            output_filter_only_first
        return
    fi

    log-debug "Running search..." >&2
    if [[ -t 1 ]] || [[ "$force_interactive" == "1" ]]; then
        log-debug "Running interactive" >&2
        # Running in a terminal, pipe to interactive fzf
        fzf_result=$(echo -e "$data" |
            fzf -q "$search_term")
        echo "$fzf_result" | output_filter_only_first
    else
        # Piping output to somewhere else, just spit out the list
        log-debug "Non-interactive, using grep"
        if [[ -z "$search_term" ]]; then
            echo -e "$data" |
                output_filter_only_first
        else
            echo -e "$data" |
                grep -E "${search_term}" |
                output_filter_only_first
        fi
    fi
}
