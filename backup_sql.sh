#!/bin/bash

# backup_sql.sh
#  Initial author : Meo for RL
#  Main dev : FAb
# 
#
# Spécifique à l'association : 
# Sauvegarde, compresse et crypte les 2 bases MySQL de RL.
#
# Program author :
#  - Intial programmer : Meo
#  - Main programmer : faydc (fab)
#
# Revision :
# -$Author: fab $
# -$Date: 2016-05-29 22:32:19 +0200 (Sun, 29 May 2016) $
# -$Revision: 150 $
#
# Licence : GPL v3


#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
LIB_PATH=$(dirname $0)
. $LIB_PATH/boot.sh

ME=$0

#
#
#
function do_zip()
{
    base=$1

    zip -qr9 -P $ZIP_PASSWD $BAK_DIR/$base.sql.zip $BAK_DIR/$base.sql 2>>$ERR_FILE
    res=$?
    if [ $res -eq 0 ]; then
        csum=`checkSum $BAK_DIR/$base.sql.zip 2>>$ERR_FILE`
        size=`sizeOf $BAK_DIR/$base.sql.zip 2>>$ERR_FILE`
        echo $csum > $BAK_DIR/$base.sql.zip.csum
        fileLogger "[ ok ] backup $base.sql OK ($size octets)"
    else
        rm -f $BAK_DIR/$base.sql.zip
        fileLogger  "[ KO ] zip $base.sql ERR (code $res)"
        hasFailed
    fi

}


#bERROR=0 #deprecated
GENERAL_SUCCESS=$EXIT_SUCCESS

function doZip()
{
    toZip=$1
    zip -qr9 -P $ZIP_PASSWD $BAK_DIR/${toZip}.sql.zip $BAK_DIR/${toZip}.sql 2>>$ERR_FILE
    res=$?
    if [ $res -eq 0 ]; then
      csum=`checkSum $BAK_DIR/${toZip}.sql.zip 2>>$ERR_FILE`
      size=`sizeOf $BAK_DIR/${toZip}.sql.zip 2>>$ERR_FILE`
      echo $csum > $BAK_DIR/${toZip}.sql.zip.csum
      fileLogger "$ok backup ${toZip}.sql $size octets)"
    else
      rm -f $BAK_DIR/$base.sql.zip
      fileLogger  "$KO zip ${toZip}.sql (code $res)"
      bERROR=1
    fi
    rm -f $BAK_DIR/${toZip}.sql 2>>$ERR_FILE
}


# dumpBase $serveur $base $user $passwd $*
#          $1       $2    $3    $4	le reste
#
# L'option mysqldump -l (lock-tables) garantit l'intégrité des bases (l'idéal
# étant de désactiver l'accès au site lors du backup).
# Ajout de l'option --ignore-table=database.table pour sauvegarder le forum
#          malgré la taille immense de table punsearch.
#
function dumpBase()
{

    srv=$1
    base=$2
    user=$3
    pass=$4
    exclude=''

    rm -f BAK_DIR/$base.sql.zip
    if [ "x$srv" = "x" ]; then
        fileLogger "$KO $0 : pas de serveur indiqué... abandon"
        hasFailed
        return 1
    fi
    if [ "x$base" = "x" ]; then
        fileLogger "$KO $0 : pas de base SQL indiquée... abandon"
        hasFailed
        return 1
    fi
    if [ "x$user" = "x" ]; then
        fileLogger "$KO $0 : user vide... abandon"
        hasFailed
        return 1
    fi
    if [ "x$pass" = "x" ]; then
        fileLogger "$KO $0 : passwd est vide... abandon"
        hasFailed
        return 1
    fi

    if [ "x$5" != "x" ]; then
        shift; shift; shift; shift; #drop $1 $2 $3 $4 for $@
        for table in $@
        do
            exclude="$exclude --ignore-table=${base}.${table}"
            name=${base}.${table}
            ## Attention au -n pour pas créer de DB
            mysqldump -h $srv -u $user -p$pass -l -n $base $table \
                1>$BAK_DIR/${name}.sql 2>>$ERR_FILE
            res=$?
            if [ $res -eq 0 ]; then
                doZip ${name}
            else
                fileLogger "mysqldump -h $srv -u $user -pPASSWORD -l -n $base $table"
                fileLogger "mysqldump has failed (rc=$res)"
                hasFailed
            fi
        done

    fi

    # bug ! Fallait pas le -B
    mysqldump -h $srv -u $user -p$pass $exclude -l $base \
        1>$BAK_DIR/$base.sql 2>>$ERR_FILE
    res=$?

    if [ $res -eq 0 ]; then
        doZip $base
        let iNbTargetOk++
    else
        hasFailed
        fileLogger "$KO mysqldump $base ERR (code $res)"
    fi
}

# Main

if [ ! \( -d $BAK_DIR -a -w $BAK_DIR \) ]; then
  fileLogger "$KO ERR dossier `basename $BAK_DIR` inaccessible"
  exit 1
fi
if [ ! -f $BAK_DIR/.htaccess ]; then
  fileLogger "$KO ERR fichier .htaccess inaccessible"
  rm -f $BAK_DIR/$SQL_BASE1.sql.zip $BAK_DIR/$SQL_BASE2.sql.zip
  exit 1
fi
if [ "x$ZIP_PASSWD" = "x" ]; then
    msg="$KO ZIP_PASSWD est vide... abandon"
    fileLogger "$msg"
    echo "$msg" | notify_email_stdin
    exit 1
fi

let iNbTargetOk=0
cd $BAK_DIR
debug "dumpBase $SQL_SERVER1,$SQL_BASE1,$SQL_USER1,$SQL_PASSWD1"
dumpBase $SQL_SERVER1 $SQL_BASE1 $SQL_USER1 $SQL_PASSWD1 $SQL_TABLES1

# 2016-05-29 Sur la demande d'olivier
#debug "dumpBase $SQL_SERVER2,$SQL_BASE2,$SQL_USER2,$SQL_PASSWD2"
#dumpBase $SQL_SERVER2 $SQL_BASE2 $SQL_USER2 $SQL_PASSWD2


# if [ $GENERAL_SUCCESS -eq $EXIT_FAILURE ]; then
#     if [ $bUseMailWarning -eq 1 ]; then
#         view_today_logs| notify_email_stdin
#     fi
#fi

if [ $GENERAL_SUCCESS -eq $EXIT_SUCCESS ]; then
    sLabel="[KO]"
elif [ $iNbTargetOk -ne 2 ]; then
    sLabel="[KO]"
else
    sLabel="[ok]"
fi

if [ $bUseMailWarning -eq 1 ]; then
    sReport="$sLabel[$iNbTargetOk/2] DB saved"
    view_today_logs| notify_email_stdin "$sReport"
fi


exit $GENERAL_SUCCESS
