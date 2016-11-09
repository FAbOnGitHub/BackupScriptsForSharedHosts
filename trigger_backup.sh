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

# À configurer dans les fichiers de conf plutôt!
DEBUG=0
#DEBUG=1


FALSE=0
TRUE=1

function trigger_action()
{
    target="$1"
    sWgetMsg=""
    wget $wget_quiet -t 3 --no-check-certificate --auth-no-challenge \
         -U $HTTP_AGENT \
         -P $BAK_DIR "${CMD_URL}?action=$target" -O - 2>> $ERR_FILE
    rc=$?
    if [ $rc -eq 0 ]; then
        status="$ok"        
    else
        status="$KO"
        sWgetMsg=":"$(wget_translate_error $rc )
    fi
    fileLogger "$status wget ${CMD_URL}?action=$target (rc=${rc}${sWgetMsg})"
    reportByMail "$status wget ${CMD_URL}?action=$target (rc=${rc}${sWgetMsg})"
    return $rc
}

# ###########################################################################
#
#         Main
#
# ###########################################################################
#set -x
DATE=$(date +"%Y%m%d-%H%M%S")
GENERAL_SUCCESS=$EXIT_SUCCESS
fileLogger  "$ok $ME starting  >>>>>"
echo "$DATE start" >> $ERR_FILE

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
LOG_URL="$(echo "$BAK_URL"|cut -d'@' -f2-)"


rc_global=0
for arg in $@
do
    case $arg in
        'mysql'|'web'|'wiki'|'sql'|'check')
            trigger_action $arg
            rc=$?
            let rc_global+=$rc
        ;;
        *)
            error "unknown commmand"
        ;;
    esac
done
fileLogger "$ok $ME stopping <<<<<< "
exit $rc_global
