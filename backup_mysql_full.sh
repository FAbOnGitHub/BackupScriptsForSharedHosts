#!/bin/bash
##############################################################################
#
# do_full_backup crée avec cs par fab le '2012-03-17 20:01:02'
#
# Objectif : faire un backup de toutes les bases de la machine
#  dans un fichier pour chacune. Ce script est intégré à l'ensemble
#  utilisé pour le projet de RL où le but est de permettre la
#  sauvegarde partielle d'une machine mutualisée.
#  Ce script sert aussi dans le cas inverse, où on dispose d'un serveur
#  dédiée partagé dont on voit toutes les bases. Lors d'une retauration on
#  ne voudra qu'une base en particulier.
#
#  Le dump crée un fichier sans timestamp pour éviter une prolifération.
#  Ce n'est pas lui qui décide de la politique de rétention.
#
# Author: Fabrice Mendes
# Last Revision :
# - $Revision: 140 $
# - $Author: fab $
# - $Date: 2015-04-14 21:52:57 +0200 (Tue, 14 Apr 2015) $
#
#
# Licence : GPL v3
#
######################################################(FAb)###################

## Considérations
# Please have a lot at Docs/Difficulties/mysqldump*


ME=$0

#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
\cd "$(dirname $0)"; LIB_PATH="$PWD"; \cd - >/dev/null;
. $LIB_PATH/boot.sh


[ "x$MYSQL_USER" = "x" ] && die "$KO \$MYSQL_USER is empty"
[ "x$MYSQL_PASS" = "x" ] && die "$KO \$MYSQL_PASS is empty"
[ "x$MYSQL_HOST" = "x" ] && die "$KO \$MYSQL_HOST is empty"

if [ "x$MYSQL_PORT" = "x" ]; then
    MYSQL_PORT=3306
fi

#export MYSQL_PWD="$MYSQL_PASS"  #better than '-p$MYSQL_PASS' but not enough
MYSQL_SESAME=
mysql_prepare_connexion "$MYSQL_HOST" "$MYSQL_USER" "$MYSQL_PASS" "$MYSQL_PORT"

bDoCompress=${bDoCompress:-1}
bDoCompressAll=${bDoCompressAll:-1}
bDoCypher=${bDoCypher:-0}
bDoXfer=${bDoXfer:-0}

date=$(date  +"%Y%m%d")
TASK_NAME=${TASK_NAME:-'mysql'}
build_archive_prefix
DIR="${ARCHIVE_PREFIX}.MySQL_complete"
dir="$DIR.$date"

MYSQL_DB_EXCLUDE_PREFIX=${MYSQL_DB_EXCLUDE_PREFIX:-""}

# Oups ! Désormais on sauvegarde tout, comme des pros !
mysql_opt="--routines --triggers --comments --dump-date --extended-insert "
mysql_opt="$mysql_opt --quick -C --set-charset"

# 2 Get name of databases
if [ "x$MYSQL_DB_EXCLUDE_PREFIX" = "x" ]; then
    declare -a aDB=( $(echo "SHOW DATABASES; " \
        | mysql --defaults-file="$MYSQL_SESAME" -N ) )
else
    declare -a aDB=( $(echo "SHOW DATABASES; " \
        | mysql --defaults-file="$MYSQL_SESAME" -N \
        | grep -v -e "^$MYSQL_DB_EXCLUDE_PREFIX" ) )
fi
rc=$?
[ $rc -ne $EXIT_SUCCESS ] && die "$KO cannot retrieve databases"

if [ ${#aDB[*]} -eq 0 ]; then
    die " $KO no databases found."
fi

cd $BAK_DIR
rm -rf $dir
mkdir -m 0700 $dir
cd $dir || die "Cannot access to dir '$dir'"

#Loop
let iNbTargetOk=0
let iNbTargetErr=0
let iCountThisOne=1
let iSkipThisOne=0
for db in ${aDB[*]}
do
    date=$(date  +"%Y%m%d-%H%M%S")
# 3 Save each DB
    case "$db" in
        "information_schema"|"performance_schema")
            let iCountThisOne=0
            let iSkipThisOne++
            #sLock="--skip-lock-tables"
            fileLogger "$ok '$db' skipped ${date} "
            continue # New ; skip virtual databases
            ;;
        *)
            let iCountThisOne=1
            taskCount
            #sLock="-l";;
            ;;
    esac

    dumpfile="${db}_${date}.sql"
#    dumpfile="${db}.sql"

    if [ $bFake -eq 1 ]; then
	echo "Ok fake $dumpfile $(date)" > "$dumpfile"
	rc=0
    else
	mysqldump --defaults-file="$MYSQL_SESAME" $MYSQL_OPT $sLock $mysql_opt ${db} >"$dumpfile" 2>>$ERR_FILE
	rc=$?
    fi
    if [ $rc -ne $EXIT_SUCCESS ]; then
        fileLogger "$KO '$db' failed (rc=$rc)"
        let iNbTargetErr++
        taskErr
        continue
    else
        size="$(du -sh "$dumpfile" | awk '{print $1 " " $2}')"
        fileLogger "$ok '$db' dumped @${date}, $size"
        taskOk
        let iNbTargetOk+=$iCountThisOne
    fi

done

cd ..
buffer="$(du --si -s "$dir")"
fileLogger "$ok $L_DUMP $buffer"

if [ $bDoCompressAll -eq 1 ]; then
    do_compress_clean  "$DIR".zip "$dir"
    rc_x=$?
    # $f_current est à jour
    bundle="$f_current"
else
    bundle="$dir"
fi

do_moveXferZone "$bundle"
rc=$?
taskAddAndStatus $rc
# rm -rf "$dir" # done by do_moveXferZone


mysql_clean_up
### Reporting
taskReportStatus
sReport="$_taskReportLabel DB saved "
logStop "$sReport"
reportByMail "$sReport" "$ME"

#exit $_iNbTaskErr
mainExit $_iNbTaskErr
