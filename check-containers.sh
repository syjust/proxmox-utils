#!/bin/bash
source ~/.log.inc.sh

# {{{ function usage
#
usage() {
    info "USAGE : $0 [OPTIONS]"
    log
    log "Where OPTIONS are :"
    log "* -h|--help                   print this usage"
    log "* -r|--running-only           show only RUNNING containers"
    log "* -s|--stopped-only           show only STOPPED containers"
    log "* -C|--sort-by-container-id   sort by ID (default behavior)"
    log "* -N|--sort-by-hostname       sort by NAME"
    log "* -S|--print-sum              print sum for memory & cores"
}
export -f usage
# }}}

export CORES_SUM=0
export MEMORY_SUM=0
# {{{ function sum
# summarize memory & cores informations
#
sum() {
    export MEMORY_SUM=$(($MEMORY_SUM+$1))
    export CORES_SUM=$(($CORES_SUM+$2))
}
export -f sum
# }}}

# {{{ function run
#
run() {
    local bar="----------------------------------------"
    local HEAD="ID NAME STATE MEM CORES ERROR"
    local BAR="$bar $bar $bar $bar $bar $bar"
    local fmt_head="%-3s %-15s %-8s %6s %5s %-.38s\n"
    local fmt_body="%-3s %-15s %-8s %6s %5s %-.35s...\n"
    local fmt_bare="%.3s %.15s %.8s %.6s %.5s %.38s\n"
    local fmt_foot="%-3s %-15s %8s %6s %5s %-.38s\n"
    local tmp_error="`mktemp /tmp/error-XXXXXXX.tmp`"
    local tmp_output="`mktemp /tmp/output-XXXXXXX.tmp`"
    local tmp_file container_id memory cores hostname State
    printf "$fmt_bare" $BAR
    printf "$fmt_head" $HEAD
    printf "$fmt_bare" $BAR
    for container_id in `lxc-ls 2>/dev/null` ; do
        eval "`lxc-info --name $container_id 2>$tmp_error | grep "State" | sed 's/:[[:blank:]]\{1,\}/=/'`"
        eval "`grep -E "(memory|cores|hostname)" /etc/pve/nodes/prox-sloth/lxc/$container_id.* | sed 's/:[[:blank:]]\{1,\}/=/'`"
        printf "$fmt_body" $container_id $hostname $State $memory $cores "`cat $tmp_error | tr '\n' ' / '`" | grep -E "$FILTER"
        if [ $? -eq 0 ] ; then
            sum $memory $cores
        fi
    done > $tmp_output
    cat $tmp_output | sort -k $FIELD
    printf "$fmt_bare" $BAR
    [ $PRINT_SUM -eq 1 ] \
        && printf "$fmt_foot" "" "" "SUM:" $MEMORY_SUM $CORES_SUM "" \
        && printf "$fmt_bare" $BAR

    for tmp_file in ${!tmp_*} ; do
        [ ! -z "${!tmp_file}" ] && [ -f "${!tmp_file}" ] && rm ${!tmp_file}
    done
}
export -f run
# }}}

# Default args
FIELD=1 
PRINT_SUM=0
FILTER="^.*$"

# get args
while [ ! -z "$1" ] ; do
    case $1 in
        -h|--help)                 usage ; exit  ;;
        -C|--sort-by-container-id) FIELD=1       ;;
        -N|--sort-by-hostname)     FIELD=2       ;;
        -S|--print-sum)            PRINT_SUM=1   ;;
        -r|--running-only)         FILTER="RUN"  ;;
        -s|--stopped-only)         FILTER="STOP" ;;
        *) quit "WTF '$1'" ;;
    esac
    shift
done

run
