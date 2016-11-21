#!/bin/bash
# trigger_backup.sh : FAb
#
# EN:
#  Launch backup $*. Use it when cron is inoperand
#
# FR:
#  Essaie de lancer les backup du serveur distant en cas de défaillance cron
#
#
# Licence : GPL v3
#


#set -x
#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
LIB_PATH=$(dirname $0)
. $LIB_PATH/boot.sh

bFakeWget={bFakeWget:-0}

function trigger_action()
{
    target="$1"
    sWgetMsg=""
    if [ $bFakeWget -eq 0 ]; then
        wget $wget_quiet --no-check-certificate --auth-no-challenge \
             -U $HTTP_AGENT \
             -P $BAK_DIR "${CMD_URL}?action=$target" -O - 2>> $ERR_FILE

        rc=$?
    else
        
        rc=$EXIT_SUCCESS
    fi
    if [ $rc -eq $EXIT_SUCCESS ]; then
        #status="[ok]"
        x=$ok
    else
        status="[KO]" # A single error could set all in error
        x=$KO
        sWgetMsg=":"$(wget_translate_error $rc )
    fi
    fileLogger "$x wget ${LOG_URL}?action=$target (rc=${rc}${sWgetMsg})"
    return $rc
}

# ###########################################################################
#
#         Main
#
# ###########################################################################
#set -x

# Normalement le client n'est pas obligé d'avoir la même arborescence que le
# serveur. Si c'est le cas, son répertoire BAK_DIR est BAK_DIR_CLI
[ "x$BAK_DIR_CLI" != "x" ] && BAK_DIR=$BAK_DIR_CLI
LTS_PATTERN=${LTS_PATTERN:-"4-Thu"}
TASK_NAME=${TASK_NAME:-"OutThere"}

LOG_URL="$(echo "$CMD_URL"|cut -d'@' -f2-)"

for arg in $@
do
    taskCount
    debug "$ME : arg=$arg"
    case $arg in
        'mysql'|'web'|'wiki'|'sql'|'check'|'safe')
            trigger_action $arg
            rc=$?
            taskStatus $rc
        ;;
        *)
            error "unknown commmand"
        ;;
    esac
done

### Reporting
taskReportStatus
sReport="$_taskReportLabel trigger $@ (by $ME)"
logStop "$sReport"
reportByMail "$sReport" "$ME"
exit $_iNbTaskErr
