#!/bin/bash
#
# Author :  FAb Mendes
# Licence : GPL v3
#
#  GOAL :
#   Illustrate plugin concept; Sample to backup a GitLab instance by:
#    - activating the dump (rake)
#    - copying it outside
#    - reading version of docker image
#    - sending it to XferZone
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
#  Project = GitLab-ce in a docker image : GLD
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


function at_exit()
{
    ### Reporting
    taskReportStatus
    sReport="$_taskReportLabel backup_many_dir"
    logStop "$sReport"
    reportByMail "$sReport" "$ME"
    exit $_iNbTaskErr   
}

#
#  Sample of code
#
JOB="forge"
GLD_DIR=${GLD_DIR:-"/data/forge"}
ME=$(basename $0)

GLD_TMP=$BAK_DIR/GLD/
VER_FILE=$GLD_TMP/docker-version.txt

bTestOnly=0
if [ "x$1" = "x-t" ]; then
    bTestOnly=1
    fileLogger "$ok test mode ${DIR_TO_BACKUP[*]}"
fi


if [ "x$GLD_DIR" = "x" ]; then
    fileLogger "$KO missing variable GLD_DIR (document_root)"
    die
fi
if [ "x$GLD_DOCKER_IMAGE" = "x" ]; then
    fileLogger "$KO missing variable GLD_DOCKER_IMAGE (docker id)"
    die
fi
if [ "x$GLD_DOCKER_DATA" = "x" ]; then
    fileLogger "$KO missing variable GLD_DOCKER_DATA (where is the data volume)"
    die
fi
if [ ! -d "$GLD_DOCKER_DATA" ]; then
    fileLogger "$KO GLD_DOCKER_DATA is not a directory"
    die
fi

##
## Let's play
## 
trap at_exit EXIT

# Docker dump
taskCount
docker -t $GLD_DOCKER_IMAGE exec gitlab-rake gitlab:backup:create \
       >$LOG_FILE 2>>$ERR_FILE
rc=$?
if [ $rc -ne 0 ]; then
    taskErr
    fileLogger "$KO docker dump failed"
    die
fi
taskOk

# Locate archive and version
taskCount
last_arch=$(ls -1 ${GLD_DOCKER_DATA}/backups )
if [ "x$last_arch" = "x" ]; then
    taskErr
    fileLogger "$KO not GitLab backup found"
    die
fi
d=${last_arch/\//} # Remove tar warning on leading '/'

docker inspect $GLD_DOCKER_IMAGE | grep -i image | unique > $VER_FILE
rc=$?
if [ $rc -ne 0 ]; then
    taskErr
    fileLogger "$KO docker get version: failed"
    die
fi

cp $d $GLD_TMP
if [ $rc -ne 0 ]; then
    taskErr
    fileLogger "$KO cannot copy docker backup"
    die
fi
taskOk


basename_d=$(basename "$d")
dirname_d=$(dirname "$d")
hash_d=$(echo "$dirname_d"|sha1sum|cut -c-16)
file_d="${hash_d}_${basename_d}"

cd $BAK_DIR
ARCHIVE_FILE="$BAK_DIR/${hostname}.${JOB}.${file_d}.tgz"
rm -f "$ARCHIVE_FILE"
tar zcf "$ARCHIVE_FILE" "$GLD_TMP" 2>>$ERR_FILE
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



### Reporting
taskReportStatus
sReport="$_taskReportLabel backup_many_dir"
logStop "$sReport"
reportByMail "$sReport" "$ME"
exit $_iNbTaskErr
