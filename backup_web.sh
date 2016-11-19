#!/bin/bash
# backup_web.sh v0.36
#  Initial author :  Meo
#  Main dev : FAb
#
# Sauvegarde, compresse et crypte l'arborescence web d'un compte mutualisé
# OVH.
#
# Licence : GPL v3

## TODO : change gzip by $sCompressProg  + do_moveXferZone()

#
#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
DIR=$(dirname $0) #Resolving path
cd $DIR 2>/dev/null; export LIB_PATH=$PWD; cd - >/dev/null
. $LIB_PATH/boot.sh


ARCH_FILE=$BAK_DIR/www.zip

if [ "x$ZIP_PASSWD" = "x" ]; then
    fileLogger "$KO ZIP_PASSWD est vide... abandon"
    exit 1
fi


rm -f $ARCH_FILE
# Zip is also done by do_moveXferZone
# tar is more efficient and will be able to perfom incremental backups.
# 
# zip -qr9 -P $ZIP_PASSWD $ARCH_FILE $WWW_DIR \
#     -x $BAK_DIR/\* -x $WIKI_DIR/\* -x $WWW_DIR/backup_\* \
#     -x $UPLOAD_DIR -x $WWW_DIR/upload\*
#     2>>$ERR_FILE
# rc=$?

tar c -f $ARCH_FILE \
    --exclude=$BAK_DIR \
    --exclude=$BAK_DIR_PUB \
    --exclude=$WIKI_DIR \
    --exclude=$UPLOAD_DIR \
    --exclude=$WWW_DIR/upload\* \
    $WWW_DIR
rc=$?
if [ $rc -eq 0 ]; then
    fileLogger "$ok $L_DUMP $ARCH_FILE"
    do_moveXferZone "$ARCH_FILE"
    rc=$?
else
    rm -f $ZIP_FILE
    fileLogger  "$KO $L_DUMP ERR (code $?)"
fi

logStop
exit $rc
