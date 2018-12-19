#!/bin/bash

# {{{ BASE LOG, DISPLAY & EXIT FUNCTIONS

# {{{ colors variables declaration
export    _esc="\033[0m"     # Text Reset
export  _black="\033[01;30m" # Black
export    _red="\033[01;31m" # Red
export  _green="\033[01;32m" # Green
export _yellow="\033[01;33m" # Yellow
export   _blue="\033[01;34m" # Blue
export _purple="\033[01;35m" # Purple
export   _cyan="\033[01;36m" # Cyan
export  _white="\033[01;37m" # White
export  _white_on_red="\033[1;37;41m"
# }}}

# {{{ function log
#
log() {
    local ls_args=""
    while [ "x${1:0:1}" == "x-" ] ; do
        ls_args="$ls_args $1" ; shift
    done
    echo $ls_args "[`date "+%F %T"`]: $@"
}
export -f log
# }}}

# {{{ function color_and_prefix
#
color_and_prefix() {
    local ls_args="-e"
    local color="$1" ; shift
    while [ "x${1:0:1}" == "x-" ] ; do
        ls_args="$ls_args $1" ; shift
    done
    local prefix="`echo ${FUNCNAME[1]} | tr [[:lower:]] [[:upper:]]`"
    log $ls_args "${!color}$prefix : $@${_esc}"
}
export -f color_and_prefix
# }}}

# {{{ function success
#
success() {
    color_and_prefix _white $@
}
export -f success
# }}}

# {{{ function error
#
error() {
    color_and_prefix _white_on_red $@
}
export -f error
# }}}

# {{{ function warning
#
warning() {
    color_and_prefix _yellow $@
}
export -f warning
# }}}

# {{{ function info
#
info() {
    color_and_prefix _cyan $@
}
export -f info
# }}}

# {{{ function quit
#
quit() {
    echo
    error "${FUNCNAME[1]}: $@"
    usage
    exit 1
}
export -f quit
# }}}

# {{{ function yes_no
#
yes_no() {
    local mess="$1"
    local resp
    while true ; do
        echo "$mess (y/n) ?"
        read resp
        case $resp in
            [yY]|[yY][eE][sS]) return 0 ;;
            [nN]|[nN][oO]) return 1 ;;
            *) "'$resp' : bad resp ! please answer with 'yes' or 'no' ('y' or 'n')." ;;
        esac
    done
}
export -f yes_no
# }}}

# }}}

export DEFAULT_MAX_DAYS="+90"
export MAX_DAYS="$DEFAULT_MAX_DAYS"
export BACKUP_DIR="/var/lib/vz/backups"
export DRY_RUN=0
export DEFAULT_FORCE_YES_NO="false"
export FORCE_YES_NO="$DEFAULT_FORCE_YES_NO"
export OPTIONS=""
export ACTION=""
export ACTION_FORCE_YES_NO=""
export VERBOSE=0

# {{{ function findIt
#
findIt() {
    find $BACKUP_DIR \
        -mtime $MAX_DAYS -type f \
        \( -name "*lzo" -or -name "*log" \)
}
export -f findIt
# }}}

# {{{ function setVar
#
setVar() {
    local arg="$1"
    local var="$2"
    local value="$3"
    local replace_if_set="${4:--y}"
    [ -z "$value" ] && quit "'$arg' predicate need a valid '$var' argument"
    [ ! -z "$ACTION" ] && quit "'$arg' must be called before ACTION setting (current ACTION is '$ACTION $ACTION_OPTIONS')"
    if [ "x$replace_if_set" == "x-y" ] ; then
        eval "export $var=\"$value\""
    else
        if [ -z "${!var}" ] ; then
            eval "export $var=\"$value\""
        else
            if [ $VERBOSE -eq 1 ] ; then
                warning "'$arg' predicate : '$var' is already set, we can't replace it by '$value'"
            fi
        fi
    fi
}
export -f setVar
# }}}

# {{{ function usage
#
usage() {
    echo
    info "USAGE : $0 [OPTIONS] ACTION"
    log
    info "WHERE ACTIONs are :"
    log "    -H|-h|--help      print this message"
    log "    -D                do a 'du -sch' (by default, this ACTION is NON-interactive)"
    log "    -L                do a 'ls -lhtr' (by default, this ACTION is NON-interactive)"
    log "    -R                do a 'rm -fv' (the effective clean action) : this activate interactive mode if "
    info "AND WHERE OPTIONS can be :"
    log "    -m MAX_DAYS       change maxdays value (default is $DEFAULT_MAX_DAYS)"
    log "    -i|--interactive  force validation on each action (default is $DEFAULT_FORCE_YES_NO)"
    log "    -d|--dry-run      display action to perform and exit"
    log "    -v|--verbose      be more verbose"
    log "    -o|--options      change default options for ACTION given (this predicate add --interactive mode by default)"
    log "                      (ie: with -D, '-sch' are default options for 'du')"
    log
    info "Notes :"
    log "    * if OPTIONS are called before ACTION : the OPTIONS predicate override default ACTION behavior (ie: interactive for -D or -L)"
    log "    * -H -D -L -R ACTIONS are exclusives"
    echo
}
export -f usage
# }}}

# {{{ function doAction
#
doAction() {
    local action="$1"
    local options="$2"
    local interactive="${3:-false}"
    local question="Are you sure you want perform '$action $options' on files from '$BACKUP_DIR' directory with '$MAX_DAYS' max older days' now"
    local file
    if [ $DRY_RUN -eq 1 ] ; then
        if [ "x$interactive" == "xtrue" ] ; then
            if (yes_no "$question (dry-run)") ; then
                for file in `findIt` ; do
                    info "[DRY-RUN With confirmation] $action $options $file"
                done
            else
                warning "[DRY-RUN With confirmation] $action $options : action aborted"
            fi
        else
            for file in `findIt` ; do
                info "[DRY-RUN] $action $options $file"
            done
        fi
    else
        if [ "x$interactive" == "xtrue" ] ; then
            if (yes_no "$question") ; then
                $action $options `findIt`
            else
                warning "$action $options : action aborted"
            fi
        else
            $action $options `findIt`
        fi
    fi
}
export -f doAction
# }}}

# {{{ function setAction
#
setAction() {
    if [ ! -z "$ACTION" ] ; then
        if [ $VERBOSE -eq 1 ] ; then
            warning "ACTION is already set (I can't replace current ACTION:'$ACTION' by new one '$1')"
        fi
        quit "-H -D -L -R ACTIONS are exclusives"
    fi
    export ACTION="$1"
}
export -f setAction
# }}}

[ -z "$1" ] && quit "I need an ACTION at least to work"
while [ ! -z "$1" ] ; do
    case $1 in
        # ACTIONS
        -H|-h|--help) usage ; exit ;;
        -D) setVar "$1" ACTION_OPTIONS "-sch" -n  ; setAction "du" ; ACTION_FORCE_YES_NO="$FORCE_YES_NO" ; shift ;;
        -L) setVar "$1" ACTION_OPTIONS "-lhtr" -n ; setAction "ls" ; ACTION_FORCE_YES_NO="$FORCE_YES_NO" ; shift ;;
        -R) setVar "$1" ACTION_OPTIONS "-fv" -n   ; setAction "rm" ; ACTION_FORCE_YES_NO="true" ; shift ;;
        # SCRIPT OPTIONS
        -m)                setVar "$1" MAX_DAYS "$2"       ; shift 2 ;;
        -d|--dry-run)      setVar "$1" DRY_RUN  "1"        ; shift   ;;
        -i|--interactive)  setVar "$1" FORCE_YES_NO "true"   ; shift   ;;
        -o|--options)      setVar "$1" ACTION_OPTIONS "$2" ; shift 2
                           setVar "$1" FORCE_YES_NO "true" ;;
        -v|--verbose)      setVar "$1" VERBOSE "1"         ; shift   ;;
        # UNVALID ARGUMENT
        *) quit "'$1' is not a valid predicate"   ;;
    esac
done

if [ -z "$ACTION" ] ; then
    quit "I need an ACTION at least to work (WTF !!!)"
else
    doAction $ACTION $ACTION_OPTIONS $ACTION_FORCE_YES_NO
fi
