#!/usr/bin/zsh

function kc() {
    kubectl "$@";
}

function kc-pod-names() {
    name_filter="$1"
    if [[ -n "$name_filter" ]]; then
        kubectl get pods | cut -d ' ' -f1 | tail -n +2 | grep "^${name_filter}"
    else
        kubectl get pods | cut -d ' ' -f1 | tail -n +2
    fi
}

function kc-pod() {
    pod_name="$1"
    n="${2:-"1"}"
    kc-pod-names | grep "$pod_name" | sed -n "${n}p"
}

function kc-context() {
    kubectl config use-context ${1}
}

function kc-dashboard() {
    echo "Starting kubectl proxy, leave this open to maintain the connection.";
    xdg-open http://localhost:8017/ui && kubectl proxy -p 8017
}

function kc-exec() {
    pod_name="$1"
    logfile="${2:-"app.log"}"
    N="${3:-"100"}"
    echo "kubectl exec -it `kc-pod $1` bash"
    kubectl exec -it "$(kc-pod "$pod_name")" -- bash
}

function kc-rolling-update() {
    pod_search_term="$1"
    confirm_yes="${2:-"y"}"

    echo -e "Rolling update: \n $(kc-pod-names "${pod_search_term}")\n"
    if [[ -n $confirm_yes ]]; then
        REPLY="$confirm_yes"
    else
        echo "Are you sure [Yy]?"
        read -k 1
        echo
    fi
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
       echo "Wasn't Y/y, quitting"
       return 1
    fi

    desired_running="$(kc-pods-running "$pod_search_term")"

    kc-pod-names "${pod_search_term}" | while read pod_name; do
        echo "Deleting $pod_name";
        kc delete pod "$pod_name";
        sleep 5;
        until $([[ ! $(kc-pods-running "$pod_search_term") < "$desired_running" ]]); do
            echo "Waiting, $(kc-pods-running "$pod_search_term")/$desired_running running..."
            sleep 5;
        done
        echo "$(kc-pods-running "$pod_search_term")/$desired_running running, continuing"
    done
}

function kc-pods-running() {
    # Gets pods that are fully up and running (Running status and 1/1 or 2/2 status)
    pod_search_term="$1"
    kc get pods | grep "^${pod_search_term}" | grep "Running" | awk '{print $2}' | bc | grep "1" | wc -l
}

# AerisWeather specific log config
function kc-tail() {
    pod_name="$1"
    logfile="${2:-"app.log"}"
    n="${3:-"100"}"
    echo "kubectl exec $(kc-pod "$pod_name") -- find /var/log/app/ | grep -E '${logfile}' | sort -r | head -n 1 | xargs tail -n ${n} -f "
    kubectl exec $(kc-pod "$pod_name") -- /bin/bash -c "find /var/log/app/ | grep -E '${logfile}' | sort -r | head -n 1 | xargs tail -n ${n} -f "
}

function kc-grep() {
    pod_name=$1
    pattern=$2

    CMD="grep -E \"${pattern}\" /var/log/app/ap*.log";
    kube-exec ${pod_name} "${CMD}";
}
