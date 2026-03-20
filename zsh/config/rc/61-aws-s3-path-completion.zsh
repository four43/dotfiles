# Dynamic S3 path tab-completion using `aws s3 ls`
#
# Completes s3://bucket/key paths for:
#   - `aws s3` commands (cp, mv, ls, rm, sync, etc.)
#   - Custom aws-s3-* functions (aws-s3-cat, aws-s3-edit, etc.)
# Also completes local file paths for commands that support both (cp, mv, sync).

zmodload zsh/datetime

typeset -gA _aws_s3_cache
typeset -gA _aws_s3_cache_time
_AWS_S3_CACHE_TTL=30

# Cached wrapper around aws s3 ls
_aws_s3_ls_cached() {
    local key="$*"
    local now=$EPOCHSECONDS

    if [[ -n "${_aws_s3_cache_time[$key]}" ]] && (( now - _aws_s3_cache_time[$key] < _AWS_S3_CACHE_TTL )); then
        print -r -- "${_aws_s3_cache[$key]}"
        return
    fi

    local result
    result="$(aws s3 ls $@ --page-size 50 --no-paginate 2>/dev/null)"
    _aws_s3_cache[$key]="$result"
    _aws_s3_cache_time[$key]=$now
    print -r -- "$result"
}

# Zsh completion function: S3 paths only
_complete_s3_path() {
    local cur="${words[CURRENT]}"

    if [[ "$cur" != s3://* ]]; then
        compadd -S '' -- 's3://'
        return
    fi

    local without_scheme="${cur#s3://}"

    if [[ "$without_scheme" != */* ]]; then
        # Complete bucket names - use -p to separate the s3:// prefix
        # so zsh filters candidates by the typed bucket name portion
        local -a buckets
        buckets=("${(@f)$(_aws_s3_ls_cached | awk '{print $3}')}")
        compadd -S '/' -p 's3://' -- "${buckets[@]}"
    else
        # Complete within bucket
        # base = everything up to and including the last /
        local base="${cur%/*}/"
        local output
        output="$(_aws_s3_ls_cached "$cur")"

        local -a entries
        entries=()
        while IFS= read -r line; do
            if [[ "$line" == *"PRE "* ]]; then
                # Directory prefix (already has trailing /)
                entries+=("${line##*PRE }")
            elif [[ -n "$line" ]]; then
                # File object
                entries+=("$(print "$line" | awk '{print $NF}')")
            fi
        done <<< "$output"

        # Use -p so zsh matches only the portion after base against typed input
        compadd -S '' -p "$base" -- "${entries[@]}"
    fi
}

# Zsh completion function: S3 paths + local file paths (for cp/mv/sync)
_complete_s3_or_local_path() {
    local cur="${words[CURRENT]}"

    if [[ "$cur" == s3://* ]]; then
        _complete_s3_path
    else
        # Offer both s3:// prefix and local file paths
        compadd -S '' -- 's3://'
        _files
    fi
}

# Zsh completion function: aws command with S3 path support + standard completer fallback
_aws_with_s3_paths() {
    if [[ "${words[CURRENT]}" == s3://* ]]; then
        _complete_s3_path
    else
        # For s3 subcommands that take local paths (cp, mv, sync), add file completion
        if [[ "${words[*]}" == *" s3 cp "* || "${words[*]}" == *" s3 mv "* || "${words[*]}" == *" s3 sync "* ]]; then
            compadd -S '' -- 's3://'
            _files
        else
            local completer
            completer="$(whence -cp aws_completer 2>/dev/null)"
            [[ -n "$completer" ]] && _bash_complete -C "$completer"
        fi
    fi
}

# Register completions
compdef _aws_with_s3_paths aws
compdef _complete_s3_path aws-s3-cat aws-s3-edit aws-s3-cp-latest aws-s3-prefix-sizes
