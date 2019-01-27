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
