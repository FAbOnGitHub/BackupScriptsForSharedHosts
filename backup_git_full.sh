#!/bin/bash
##############################################################################
# $Id: backup_svn_full.sh 140 2015-04-14 19:52:57Z fab $
# do_full_backup crée avec cs par fab le '2012-03-17 20:01:02'
VERSION=0.0.1
# Objectif : faire un backup de tous les dépôts GIT de la machine
#  dans un fichier pour chacune. Ce script est intégré à l'ensemble
#  utilisé pour le projet de RL où le but est de permettre la
#  sauvegarde partielle d'une machine mutualisée.
#  Ce script sert aussi dans le cas inverse, où on dispose d'un serveur
#  dédiée partagé dont on voit toutes les bases. Lors d'une retauration on
#  ne voudra qu'une base en particulier.
#
#  Le dump crée un fichier sans timestamp pour éviter une prolifération.
#  Ce n'est pas lui qui décide de la politique de rétention.
#
# Author: Fabrice Mendes
# Last Revision :
# - $Revision: 140 $
# - $Author: fab $
# - $Date: 2015-04-14 21:52:57 +0200 (Tue, 14 Apr 2015) $
#
######################################################(FAb)###################

ME=$0


#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
\cd "$(dirname $0)"; LIB_PATH="$PWD"; \cd - >/dev/null;
. $LIB_PATH/boot.sh

bDoCompress=${bDoCompress:-1}
bDoCompressAll=${bDoCompressAll:-1}
bDoCypher=${bDoCypher:-0}
bDoXfer=${bDoXfer:-0}

date=$(date  +"%Y%m%d")
h=$(hostname -s)
DIR="$h.GIT_complete"
dir="$DIR.$date"

[ "x$GIT_DIR" = "x" ] && die " $KO \$GIT_DIR not configured"

# 2 Get name of git repos (aka databases)
declare  -a aDB=( $(find "$GIT_DIR" -maxdepth 1 -mindepth 1 -type d ) )
rc=$?
[ $rc -ne $EXIT_SUCCESS ] && die "$KO cannot retrieve GIT"

if [ ${#aDB[*]} -eq 0 ]; then
    die " $KO no databases found."
fi

cd $BAK_DIR
rm -rf $dir
mkdir -m 0700 $dir
cd $dir || die "Cannot access to dir '$dir'"

#Loop
let iNbDbTotal=${#aDB[*]}
let iNbDbOk=0
for db in ${aDB[*]}
do
    # 3 Save each DB
    taskCount
    date=$(date  +"%Y%m%d-%H%M%S")
    dumpfile="$(basename ${db})"".svndump"
    cd "$db"
    git bundle create "../$dumpfile" --all >/dev/null 2>>$ERR_FILE
    rc=$?    
    cd - >/dev/null
    if [ $rc -ne $EXIT_SUCCESS ]; then
        fileLogger "$KO failure on '$db' found @${date} $size"
        error "$KO git bundle create '$db' failed (rc=$rc)"
        taskErr
        continue
    else
        size="$(du --si -s "$dumpfile")"
        fileLogger "$ok '$db' found @${date} $size"
        taskOk
        let iNbDbOk++
    fi
done


cd ..
buffer="$(du --si -s "$dir")"
fileLogger "$buffer"

if [ $bDoCompressAll -eq 1 ]; then
    do_compress_clean "$DIR".zip "$dir"
    rc_x=$?
    # $f_current est à jour
    bundle="$f_current"
else
    bundle="$dir"
fi

do_moveXferZone "$bundle"
rc=$?
taskAddAndStatus $rc



### Reporting
taskReportStatus
sReport="$_taskReportLabel repos saved"
logStop "$sReport"
reportByMail "$sReport" "$ME"

#exit $_iNbTaskErr
mainExit $_iNbTaskErr
