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


function trigger_action()
{
    target="$1"
    sWgetMsg=""
    wget $wget_quiet --no-check-certificate --auth-no-challenge \
         -U $HTTP_AGENT \
         -P $BAK_DIR "${CMD_URL}?action=$target"  2>> $ERR_FILE
    # -O -
    rc=$?
    if [ $rc -eq 0 ]; then
        #status="[ok]"
        x=$ok
        let iNbOk++
    else
        status="[KO]"
        x=$KO
        let iNbErr++
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

GENERAL_SUCCESS=$EXIT_SUCCESS


# Normalement le client n'est pas obligé d'avoir la même arborescence que le
# serveur. Si c'est le cas, son répertoire BAK_DIR est BAK_DIR_CLI
[ "x$BAK_DIR_CLI" != "x" ] && BAK_DIR=$BAK_DIR_CLI
LTS_PATTERN=${LTS_PATTERN:-"4-Thu"}
TASK_NAME=${TASK_NAME:-"OutThere"}

if [ ! -d $BAK_DIR ]; then
    fileLogger  "$KO BAK_DIR ('$BAK_DIR') is missing"
    exit 1
fi
if [ ! -w $BAK_DIR ]; then
    fileLogger  "$KO BAK_DIR ('$BAK_DIR') is not writable"
    exit 1
fi
if [ ! -d $LTS_DIR ]; then
    fileLogger  "$KO LTS_DIR ('$LTS_DIR') is missing"
    exit 1
fi
if [ ! -w $LTS_DIR ]; then
    fileLogger  "$KO LTS_DIR ('$LTS_DIR') is not writable"
    exit 1
fi
if [ "x$BAK_URL" = "x" ]; then
    fileLogger  "\$BAK_URL is not set"
    exit 1
fi
LOG_URL="$(echo "$CMD_URL"|cut -d'@' -f2-)"

status="[ok]"
let iNbActions=0
let iNbErr=0
let iNbOk=0
rc_global=0
for arg in $@
do
    let iNbActions++
    debug "$ME : arg=$arg"
    case $arg in
        'mysql'|'web'|'wiki'|'sql'|'check'|'safe')
            trigger_action $arg
            rc=$?
            let rc_global+=$rc
        ;;
        *)
            error "unknown commmand"
        ;;
    esac
done

logStop
reportByMail "$status [$iNbOk/$iNbActions] $ME" $ME
exit $rc_global
