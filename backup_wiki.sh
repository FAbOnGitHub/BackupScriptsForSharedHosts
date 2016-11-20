#!/bin/bash
# backup_wiki.sh
#  Initial author :  Meo
#  Main dev : FAb
#
# Sauvegarde, compresse et crypte l'arborescence wiki d'un compte mutualisé
# OVH.
#
# Licence : GPL v3


#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
DIR=$(dirname $0) #Resolving path
cd $DIR 2>/dev/null; export LIB_PATH=$PWD; cd - >/dev/null
. $LIB_PATH/boot.sh


ZIP_FILE=$BAK_DIR/wiki.zip    # Archive zipée
ZIP_FILE=$BAK_DIR/wiki.tgz

if [ ! -f $BAK_DIR/.htaccess ]; then
    fileLogger "$KO ERR fichier .htaccess inaccessible"
    rm -f $ZIP_FILE
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

rm -f $ZIP_FILE
# zip -qr9 -P $ZIP_PASSWD $ZIP_FILE $WIKI_DIR \
#     2>>$ERR_FILE
# rc=$?

cd $WWW_DIR
tar zcf $ZIP_FILE $WIKI_DIR

if [ $rc -eq 0 ]; then
    fileLogger "$ok $L_DUMP $ZIP_FILE"
    bDoCompress=0
    do_moveXferZone $ZIP_FILE
    rc=$?
else
    rm -rf $ZIP_FILE
    fileLogger "$KO $L_DUMP $ZIP_FILE (rc=$rc)"
fi

logStop
exit $rc
