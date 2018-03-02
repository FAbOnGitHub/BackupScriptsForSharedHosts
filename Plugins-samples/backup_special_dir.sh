#!/bin/bash
#
# Author :  FAb Mendes 
# Licence : GPL v3
#
#  GOAL :
#   Illustrate plugin concept; Sample to backup a specific directory
#
#  REQUIREMENTS:
#   Create a directory for your plugins next to the where "lib.backup.sh" is.
#
#  EXPLANATIONS:
#  Here we just 'tar' some folders with some exclusions. You can do what you
#  want with the same roadmap :
#   1- autoload lib
#   2- declare a new task (taskCount) for reporting-system
#   3- compute an archive name
#   4- make your action to build the archive
#   5- handle errors
#   6- send it to public zone (do_moveXferZone).
#   That's all. Quite simple!
#
#
#  FR:
#   Le but est d'illustrer comment étendre le projet par des scripts plugins.
#   Il faut déposer les plugins dans un dossier parallèle à celui où est
#   "lib.backup.sh"
#
#  Project = MyVeryBigProject : MVBP
#
##############################################################################
###
### START OF AUTOLOAD
###
#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
\cd $(dirname $0); DIR=$PWD;
#Resolving path
cd ..
lib="$(find $PWD -maxdepth 2 -name "lib.backup.sh" 2>/dev/null | head -1)"
if [ "x$lib" = "x" ]; then
    echo "Cannot find lib.backup.sh. Abort" 2>&1
    exit 1
fi
DIR="$(dirname $lib)"
cd - >/dev/null
### Load library
cd $DIR 2>/dev/null; export LIB_PATH=$PWD; cd - >/dev/null
. $LIB_PATH/boot.sh
### END OF AUTOLOAD
##############################################################################


#
#  Sample of code
# 
JOB="MVBP_dir"
MVBP_DIR=${MVBP_DIR:-"/data/web_mvbp"}
ME=$(basename $0)


if [ "x$MVBP_DIR" = "x" ]; then
    fileLogger "$KO missing variable MVBP_DIR (document_root)"
    die
fi
bTestOnly=0
if [ "x$1" = "x-t" ]; then
    bTestOnly=1
    fileLogger "$ok test mode ${DIR_TO_BACKUP[*]}"
fi


for d in $MVBP_DIR
do
    taskCount
    if [ ! -r "$d" ]; then
        fileLogger "No such readable file or directory '$d'"
        taskErr
        continue
    fi

    d=${d/\//} # Remove tar warning on leading '/'
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
    tar zcf "$ARCHIVE_FILE"  \
        --exclude="$d/src/BAK_img" \
        --exclude="$d/web/vlbi_maps" \
        --exclude="$d/fab_exclusion/" \
        "$d" 2>>$ERR_FILE
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
