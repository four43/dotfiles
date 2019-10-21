function pathmunge() {
    if ! echo $PATH | grep -E -q "(^|:)$1($|:)"; then
        if [ "$2" = "after" ] ; then
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
	  cmd=$@;

	  echo "Command: ${cmd}" >&2
	  read -q "REPLY?Are you sure [Yy]? "
	  echo >&2
	  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	      exit 1
	  fi

	  eval $cmd
}

function columns() {
    tab=$(echo -e "\t")
    cat - | column -t -s "$tab"
}

# Filters output via fzf if interactive (or if force_interactive is set to 1). 
# Pass a search term as first arg, only output first column if arg2 is true
function search-output() {
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

    if [[ -t 1 ]] || [[ "$force_interactive" == "1" ]]; then
        # Running in a terminal, pipe to interactive fzf
        fzf_result=$(echo -e "$data" \
            | fzf -q "$search_term")
        echo "$fzf_result" | output_filter_only_first
    else
        # Piping output to somewhere else, just spit out the list
        if [[ -z "$search_term" ]]; then
            echo -e "$data" \
                | output_filter_only_first
       else
            echo -e "$data" \
                | grep -E "${search_term}" \
                | output_filter_only_first
        fi
    fi
}

