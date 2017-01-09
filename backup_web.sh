#!/bin/bash
# backup_web.sh v0.36
#  Initial author :  Meo
#  Main dev : FAb
#
# Sauvegarde, compresse et crypte l'arborescence web d'un compte mutualisé
# OVH.
#
# Licence : GPL v3

#
#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
<<<<<<< HEAD
DIR=$(dirname $0) #Resolving path
=======
\cd $(dirname $0); DIR=$PWD; \cd - >/dev/null; #Resolving path
>>>>>>> ea55511b64ff2d7a19b1933d5e6e224d80e66a77
cd $DIR 2>/dev/null; export LIB_PATH=$PWD; cd - >/dev/null
. $LIB_PATH/boot.sh

taskCount
ARCHIVE_FILE=$BAK_DIR/www.tgz
rm -f $ARCHIVE_FILE
# tar is more efficient and will be able to perfom incremental backups.
# Zip is also done by do_moveXferZone (no more with bDoCompress=0)
# 
# zip -qr9 -P $ZIP_PASSWD $ARCHIVE_FILE $WWW_DIR \
#     -x $BAK_DIR/\* -x $WIKI_DIR/\* -x $WWW_DIR/backup_\* \
#     -x $UPLOAD_DIR -x $WWW_DIR/upload\*
#     2>>$ERR_FILE
# rc=$?

cd $WWW_DIR
tar zcf $ARCHIVE_FILE \
    --exclude="$(basename $BAK_DIR)" \
    --exclude="$(basename $BAK_DIR_PUB)" \
    --exclude="$(basename $WIKI_DIR)" \
    --exclude="$(basename $UPLOAD_DIR)" \
    --exclude="$(basename $WWW_DIR)/upload\*"  \
    $WWW_DIR
rc=$?
if [ $rc -eq 0 ]; then    
    bDoCompress=0
    fileLogger "$ok $L_DUMP $ARCHIVE_FILE "
    do_moveXferZone "$ARCHIVE_FILE"
    rc=$?
    if [ $rc -eq $EXIT_SUCCESS ]; then
        taskOk
    else
        taskErr
    fi
else
    rm -rf $ARCHIVE_FILE
    taskErr
    fileLogger  "$KO $L_DUMP ERR (code $?). rm'."
fi


### Reporting
taskReportStatus
sReport="$_taskReportLabel web"
logStop "$sReport"
reportByMail "$sReport" "$ME"
exit $_iNbTaskErr
