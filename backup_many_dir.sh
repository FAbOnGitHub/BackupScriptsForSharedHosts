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




if [ ! -f $BAK_DIR/.htaccess ]; then
    fileLogger "$KO ERR: cannot find .htaccess in $BAK_DIR"
    exit 1
fi
if [ -f $LOCK_FILE ]; then
    fileLogger "$KO ERR missing lock file '$LOCK_FILE'... abort"
    exit 1
fi


if [ ${#DIR_TO_BACKUP[*]} -lt 1 ]; then
    fileLogger "$KO empty DIR_TO_BACKUP ... abort"
    exit 1
    
fi    

bTestOnly=0
if [ "x$1" = "x-t" ]; then
    bTestOnly=1
fi

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
    
    ARCHIVE_FILE="$BAK_DIR/${file_d}.tgz"

    if [ $bTestOnly -eq 1 ]; then
        echo "$d -> $ARCHIVE_FILE in $BAK_DIR"
        taskOk
        continue
    fi
    

    \cd "$basenane_d"
    rm -f "$ARCHIVE_FILE"  
    tar zcf "$ARCHIVE_FILE" "$d"
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
taskReportStatus
sReport="$_taskReportLabel backup_many_dir"
logStop "$sReport"
reportByMail "$sReport" "$ME"
exit $_iNbTaskErr
