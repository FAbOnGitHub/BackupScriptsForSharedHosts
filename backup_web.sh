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


ZIP_FILE=$BAK_DIR/www.zip

if [ ! \( -d $BAK_DIR -a -w $BAK_DIR \) ]; then
    fileLogger "$KO ERR dossier `basename $BAK_DIR` inaccessible"
    exit 1
fi
if [ ! -f $BAK_DIR/.htaccess ]; then
    fileLogger "$KO ERR fichier .htaccess inaccessible"
    rm -f $ZIP_FILE
    exit 1
fi
if [ "x$ZIP_PASSWD" = "x" ]; then
    fileLogger "[ KO ] ZIP_PASSWD est vide... abandon"
    exit 1
fi


rm -f $ZIP_FILE
zip -qr9 -P $ZIP_PASSWD $ZIP_FILE $WWW_DIR \
    -x $BAK_DIR/\* -x $WIKI_DIR/\* -x $WWW_DIR/backup_\* \
    -x $UPLOAD_DIR -x $WWW_DIR/upload\*
    2>>$ERR_FILE
res=$?
if [ $res -eq 0 ]; then
    csum=`checkSum $ZIP_FILE 2>>$ERR_FILE`
    size=`sizeOf $ZIP_FILE 2>>$ERR_FILE`
    echo $csum > $ZIP_FILE.csum
    fileLogger "[ ok ] zip / OK ($size octets)"
else
    rm -f $ZIP_FILE
    fileLogger  "$KO zip / ERR (code $?)"
fi
