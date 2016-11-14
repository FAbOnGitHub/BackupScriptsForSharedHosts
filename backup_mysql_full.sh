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
ME=$0
#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
DIR=$(dirname $0) #Resolving path
cd $DIR 2>/dev/null; export LIB_PATH=$PWD; cd - >/dev/null

. $LIB_PATH/boot.sh

[ "x$MYSQL_USER" = "x" ] && die "$KO \$MYSQL_USER is empty"
[ "x$MYSQL_PASS" = "x" ] && die "$KO \$MYSQL_PASS is empty"
[ "x$MYSQL_HOST" = "x" ] && die "$KO \$MYSQL_HOST is empty"
export MYSQL_PWD="$MYSQL_PASS"  #instead of '-p$MYSQL_PASS'
bDoCompress=${bDoCompress:-1}
bDoCompressAll=${bDoCompressAll:-1}
bDoCypher=${bDoCypher:-0}
bDoXfer=${bDoXfer:-0}

date=$(date  +"%Y%m%d")
h=$(hostname -s)
DIR="$h.MySQL_complete"
dir="$DIR.$date"

MYSQL_DB_EXCLUDE_PREFIX=${MYSQL_DB_EXCLUDE_PREFIX:-""}

# Oups ! Désormais on sauvegarde tout, comme des pros !
mysql_opt="--routines --triggers --comments --dump-date --extended-insert --set-charset"

# 2 Get name of databases
if [ "x$MYSQL_DB_EXCLUDE_PREFIX" = "x" ]; then
    declare -a aDB=( $(echo "SHOW DATABASES; " \
        | mysql -u $MYSQL_USER -N ) )
else
    declare -a aDB=( $(echo "SHOW DATABASES; " \
        | mysql -u $MYSQL_USER -N \
        | grep -v -e "^$MYSQL_DB_EXCLUDE_PREFIX" ) )
fi
rc=$?
[ $rc -ne $EXIT_SUCCESS ] && die "$KO cannot retrieve databases"

if [ ${#aDB[*]} -eq 0 ]; then
    die " $KO no databases found."
fi

vars="$(echo "show variables;" | mysql -u $MYSQL_USER \
                          | grep innodb_version| cut -c 16- \
                          |sed -e "s@\([0-9]\).\([0-9]\)\(.*\)@maj=\1 min=\2@")"

export $vars
#echo "[maj=$maj][min=$min]"
COMPAT56=true
if [ $maj -eq 5 ]; then
    if [ $min -ge 7 ]; then
        COMPAT56=false
    fi
elif [ $maj -gt 5 ]; then
    COMPAT56=false
fi

cd $BAK_DIR
rm -rf $dir
mkdir -m 0700 $dir
cd $dir || die "Cannot access to dir '$dir'"

date=$(date  +"%Y%m%d-%H%M%S")
#Loop
let iNbTargetOk=0
let iCountThisOne=1
let iSkipThisOne=0
for db in ${aDB[*]}
do
# 3 Save each DB
    case "$db" in
        "information_schema"|"performance_schema")
            let iCountThisOne=0
            let iSkipThisOne++
            #sLock="--skip-lock-tables"
            fileLogger "$ME '$db' skipped ${date} "
            continue # New ; skip virtual databases
            ;;
        *)
            let iCountThisOne=1
            #sLock="-l";;
            ;;        
    esac
    
#    dumpfile="${db}_${date}.sql"
    dumpfile="${db}.sql"

    mysqldump -h $MYSQL_HOST -u $MYSQL_USER $MYSQL_OPT $sLock $mysql_opt ${db} >"$dumpfile" 2>>$ERR_FILE
    rc=$?
    if [ $rc -ne $EXIT_SUCCESS ]; then
        error "$KO $ME '$db' failed (rc=$rc)"
        continue
    else
        fileLogger "$OK $ME '$db' found ${date} dump ok"
        let iNbTargetOk+=$iCountThisOne
    fi

done

cd ..
buffer="$(du --si -s "$dir")"
fileLogger "$buffer"

if [ $bDoCompressAll -eq 1 ]; then
    do_compress_clean  "$DIR".zip "$dir"
    rc_x=$?
    # $f_current est à jour

# 6 Move to xfer zone (option)
    do_moveXferZone "$f_current"
    rm -rf "$dir"
fi

# if [ $bUseMailWarning -eq 1 ]; then
#     sReport="DB saved = $iNbTargetOk / ${#aDB[*]}"
#     view_today_logs| notify_email_stdin "$sReport"
# fi

let c=${#aDB[*]}
let iSum=$iNbTargetOk+$iSkipThisOne
if [ $iSum -eq $c ]; then
    sLabel="[ok]"
else
    sLabel="[KO]"
fi

sReport="$sLabel[$iNbTargetOk+$iSkipThisOne/$c] DB saved "
reportByMail "$sReport" "$ME"

# see to use rc=$? and then exit $rc
exit $EXIT_SUCCESS



    # if [ "$db" = "performance_schema" ]; then
    #     debug  "$WARN performance_schema ignored"
    #     continue
    # fi
    # if [ "$db" = "information_schema" ]; then
    #     if [ $COMPAT56 = "false" ]; then
    #         debug  "$WARN information_schema ignored (no compat56)"
    #         continue
    #     fi
    # fi
