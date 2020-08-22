#!/usr/bin/env bash
SERVICE_NAME="clamd"
SERVICE_CONF="-c /etc/${SERVICE_NAME}.conf"

function log {
        echo `date` $ME - "$@"
}

function start {
    log "[ Starting ${SERVICE_NAME}... ]"

    PROCESS_ID=$(pidof $SERVICE_NAME) && echo "$PROCESS_ID"
    if [[ -z $PROCESS_ID ]]; then
        echo "INFO: $SERVICE_NAME process is not running. Start..."
        run="$SERVICE_NAME $SERVICE_CONF" && bash -c "${run}"
    else
        log "[ $SERVICE_NAME is already running. Nothing to start! ]"
    fi

}

function stop {
    log "[ Stoping ${SERVICE_NAME}... ]"

    PROCESS_ID=$(pidof $SERVICE_NAME)
    if [[ -z $PROCESS_ID ]]; then
        log "[ $SERVICE_NAME is not running. Nothing to stop! ]"
    else
        /usr/bin/pkill -INT ${SERVICE_NAME}
    fi
}

function restart {
    log "[ Restarting ${SERVICE_NAME}... ]"
    stop
    start
}

case "$1" in
        "start")
            start
        ;;
        "stop")
            stop
        ;;
        "restart")
            restart
        ;;
        *) echo "Usage: $0 restart|start|stop"
        ;;

esac
