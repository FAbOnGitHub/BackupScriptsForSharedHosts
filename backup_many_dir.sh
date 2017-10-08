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
    fileLogger "$KO ERR fichier .htaccess inaccessible"
    rm -f $ARCHIVE_FILE
    exit 1
fi
if [ -f $LOCK_FILE ]; then
    fileLogger "$KO ERR verrou '$LOCK_FILE' present... abandon"
    exit 1
fi

if [ "x$ZIP_PASSWD" = "x" ]; then
    fileLogger "$KO ZIP_PASSWD est vide... abandon"
    exit 1
fi

if [ ${#DIR_TO_BACKUP[*]} -lt 1 ]; then
    fileLogger "$KO pb DIR_TO_BACKUP ... abandon"
    exit 1
    
fi    

for d in ${#DIR_TO_BACKUP[*]}
do
    ARCHIVE_FILE=$BAK_DIR/${d}.tgz
    rm -f $ARCHIVE_FILE
    


taskCount

\cd $d
\cd ..
tar zcf $ARCHIVE_FILE $d
if [ $rc -eq 0 ]; then
    szArch="$(du --si -s $ARCHIVE_FILE | awk '{print $1}')"
    szDir="$(du --si -s $WIKI_DIR | awk '{print $1}')"
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
sReport="$_taskReportLabel wiki"
logStop "$sReport"
reportByMail "$sReport" "$ME"
exit $_iNbTaskErr
