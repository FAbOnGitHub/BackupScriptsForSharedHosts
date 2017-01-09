#!/bin/bash
# backup_wiki.sh
#  Initial author : FAb
#  Main dev : FAb
#
#  Backup 'Doc' and 'Sample' to build archives which should be retrieved
#  by import_test.sh
#
# Licence : GPL v3

<<<<<<< HEAD

#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
DIR=$(dirname $0) #Resolving path
=======
ME=$0
#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
#DIR=$(dirname $(readlink -f $ME) ) #Resolving path
\cd $(dirname $0); DIR=$PWD; \cd - >/dev/null;

>>>>>>> ea55511b64ff2d7a19b1933d5e6e224d80e66a77
cd $DIR 2>/dev/null; export LIB_PATH=$PWD; cd - >/dev/null
. $LIB_PATH/boot.sh

cd $BAK_DIR
taskCount
#1 Dump
sTarget1="Docs.tgz"
tar zcf $sTarget1  $LIB_PATH/Docs 2>>$ERR_FILE
rc=$?
#2 Compress
#3 Cypher
#4 Offer

if [ $rc -eq 0 ]; then
    fileLogger "$ok $L_DUMP $sTarget1"
    bDoCompress=0
    do_moveXferZone "$sTarget1"
    rc=$?
    if [ $rc -eq $EXIT_SUCCESS ]; then
        taskOk
    else
        taskErr
    fi

else
    taskErr
    fileLogger "$KO $L_DUMP $sTarget1"
fi

### Reporting
taskReportStatus
sReport="$_taskReportLabel backup test"
logStop "$sReport"
reportByMail "$sReport" "$ME"
exit $_iNbTaskErr
