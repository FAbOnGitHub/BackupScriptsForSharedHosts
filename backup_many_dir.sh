#!/bin/bash
# backup_wiki.sh
#  Initial author :  Meo
#  Main dev : FAb
#
# Sauvegarde tous les dossiers DIR_TO_BACKUP en archives individuelles
# 
#
# Licence : GPL v3

#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
\cd $(dirname $0); DIR=$PWD; \cd - >/dev/null;
 #Resolving path
cd $DIR 2>/dev/null; export LIB_PATH=$PWD; cd - >/dev/null
. $LIB_PATH/boot.sh

JOB="Directory"

let c=${#DIR_TO_BACKUP[*]}
if [ $c -lt 1 ]; then
    fileLogger "$KO empty DIR_TO_BACKUP (c=$c) ... abort"
    exit 1
    
fi    

bTestOnly=0
if [ "x$1" = "x-t" ]; then
    bTestOnly=1
    fileLogger "$ok test mode ${DIR_TO_BACKUP[*]}"
fi

ME=$(basename $0)
#me_log=$(mktemp /tmp/${ME}_XXXXXX) #$ERR_FILE

for d in ${DIR_TO_BACKUP[*]}
do
    taskCount
    
    if [ ! -r "$d" ]; then
        fileLogger "No such file or directory '$d'"
        taskErr
        continue
    fi

    
    basename_d=$(basename "$d")
    dirname_d=$(dirname "$d")
    hash_d=$(echo "$dirname_d"|sha1sum|cut -c-16)
    file_d="${hash_d}_${basename_d}"
    
    ARCHIVE_FILE="$BAK_DIR/${hostname}.${JOB}.${file_d}.tgz"

    if [ $bTestOnly -eq 1 ]; then
        echo "$d -> $ARCHIVE_FILE"
        taskOk
        continue
    fi
    

    \cd "$basenane_d"
    rm -f "$ARCHIVE_FILE"  
    tar zcf "$ARCHIVE_FILE" "$d" 2>>$ERR_FILE
    rc=$?
    if [ $rc -eq 0 ]; then
        szArch="$(du --si -s $ARCHIVE_FILE | awk '{print $1}')"
        szDir="$(du --si -s $d | awk '{print $1}')"
        fileLogger "$ok $L_DUMP $ARCHIVE_FILE ($szDir->$szArch)"
        bDoCompress=0
        do_moveXferZone $ARCHIVE_FILE
        rc=$?
        if [ $rc -eq $EXIT_SUCCESS ]; then
            taskOk
        else
            taskErr
        fi
    else
        taskErr
        rm -rf $ARCHIVE_FILE
        fileLogger "$KO $L_DUMP $ARCHIVE_FILE (rc=$rc)"
    fi

done

### Reporting
cat $me_log >>$LOG_FILE
taskReportStatus
sReport="$_taskReportLabel backup_many_dir"
logStop "$sReport"
reportByMail "$sReport" "$ME"
exit $_iNbTaskErr
