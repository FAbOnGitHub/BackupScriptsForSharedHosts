#!/bin/bash
# import_backup.sh2  Meo, FAb & RL
#
# Fait le ménage dans le dossier LTS (LTS_DIR) en fonction du paramètre
#  passé ou de la limite fixée dans la configuration
#
#  Possibilité de forcer à un nombre de jours de retenue $1
#  Quota (%) à essayer d'atteindre $2, par défaut $DISK_USAGE_WARNING
#
# Licence : GPL v3
#


#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
\cd "$(dirname $0)"; LIB_PATH="$PWD"; \cd - >/dev/null;
. $LIB_PATH/boot.sh

FALSE=0
TRUE=1

# ###########################################################################
#
#         Main
#
# ###########################################################################
#set -x
DATE=$(date +"%Y%m%d-%H%M%S")
GENERAL_SUCCESS=$EXIT_SUCCESS

# Délai de validité d'une archive téléchargée
#let maxTime=3600*28


# Normalement le client n'est pas obligé d'avoir la même arborescence que le
# serveur. Si c'est le cas, son répertoire BAK_DIR est BAK_DIR_CLI
## removed # [ "x$BAK_DIR_CLI" != "x" ] && BAK_DIR=$BAK_DIR_CLI
TASK_NAME="import_clean_LTS"

if [ ! -d $LTS_DIR ]; then
    fileLogger  "$KO LTS_DIR ('$LTS_DIR') is missing"
    exit 1
fi
if [ ! -w $LTS_DIR ]; then
    fileLogger  "$KO LTS_DIR ('$LTS_DIR') is not writable"
    exit 1
fi

## URL à afficher dans log, sans le mot de passe
LOG_URL="$(echo "$BAK_URL"|cut -d'@' -f2-)"

iAgeArg="$1"
iAge=${iAgeArg:-180}

max="$2"
if [ "x$max" != "x" ]; then
    let iMax=${max//%/}  # Remove %
elif [ "x$DISK_USAGE_WARNING" != "x" ]; then
    let iMax=$DISK_USAGE_WARNING
else
    let iMax=80
fi

# Ok to start looping
bLoop=1

# Checks
buffer="$(df -PH $dir)"
rc=$?
if [ $rc -ne 0 ]; then
    taskCount
    bLoop=0 # do not enter main loop

    fileLogger "$KO cannot use df to determine available space"
    taskErr
fi


# Main loop ###################################################################
cd $LTS_DIR
while [ $bLoop ] 
do
    # if limit reached...
    simple_disk_space
    # Now $size $ppc and $iPPC are ready

    if [ $iPPC -le $iMax ]; then
        bLoop=0
        fileLogger "$OK $L_CLEAN LTS under limit ${iMax}% (${size})"
        continue
    fi

    oldest="$(\ find . -maxdepth 1 -type f -atime +iAge \
                \( -name "*.gpg" -o -name "*.zip" -o -name "*.rar" \
                    -o -name "*.tgz" -o -name "*.tar"  \) \
                    ) | sort -n | head -1"
    if [ "x$oldest" = "x" ]; then
        fileLogger "$WARN $L_CLEAN no file left"
        bLoop=0
        continue
    fi

    taskCount
    echo "rm $oldest"
    rc=$?
    if [ $rc -eq 0 ]; then
        taskOk
        fileLogger "$ok $L_CLEAN removing $oldest"
    else
        taskErr
        fileLogger "$KO $L_CLEAN removing $oldest failed"
    fi

done


# Conclusion ##################################################################

### Reporting
taskReportStatus
sReport="$_taskReportLabel clean LTS DIR"
logStop "$sReport"
reportByMail "$sReport" "$ME"

#exit $_iNbTaskErr
mainExit $_iNbTaskErr
