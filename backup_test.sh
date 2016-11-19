#!/bin/bash
# backup_wiki.sh
#  Initial author : FAb
#  Main dev : FAb
#
#  Backup 'Doc' and 'Sample' to build archives which should be retrieved
#  by import_test.sh
#
# Licence : GPL v3


#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
DIR=$(dirname $0) #Resolving path
cd $DIR 2>/dev/null; export LIB_PATH=$PWD; cd - >/dev/null
. $LIB_PATH/boot.sh

cd $BAK_DIR
#1 Dump
sTarget1="Doc.tgz"
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
else
    fileLogger "$KO $L_DUMP $sTarget1"
fi

logStop
exit $rc
