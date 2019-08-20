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

	  echo "Command: ${cmd}"
	  read -q "REPLY?Are you sure [Yy]? "
	  echo
	  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	      exit 1
	  fi

	  eval $cmd
}

function columns() {
    tab=$(echo -e "\t")
    cat - | column -t -s "$tab"
}
