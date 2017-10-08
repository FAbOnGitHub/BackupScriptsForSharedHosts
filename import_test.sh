#!/bin/bash
# import_backup.sh2  Meo, FAb & RL
#
# Importation de backups via wget. Rotation des backups sur la base de
# timestamps.
#
# Licence : GPL v3
#


#set -x
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

let maxTime=3600*28

LTS_PATTERN=${LTS_PATTERN:-"4-Thu"}
TASK_NAME=${TASK_NAME:-"OutThere"}

## URL à afficher dans log, sans le mot de passe
LOG_URL="$(echo "$BAK_URL"|cut -d'@' -f2-)"

# test
update_distant_list
#exit $?

BAK_FILES=${BAK_FILES:-'Docs.tar.gpg'}

# Main loop ###################################################################
declare -a aTmp=( ${BAK_FILES[*]} )
let iNbTargetTotal=${#aTmp[*]}
let iNbTargetOk=0

### Make our own test in relation with import_test.sh
###  Docs.tgz.gpg ?
for raw_file in ${BAK_FILES[*]}; do
    taskCount
    #   echo "file=$file"
    # WTF ???
    file="$raw_file"
    try=$TRUE
    #  SUCCESS=$FALSE
    SUCCESS=$TRUE

    ff=$DATE-$file
    rm -f $BAK_DIR_CLI/$ff $BAK_DIR_CLI/$file.csum

    wgetFile $file
    rc=$?
    if [ $rc -ne $EXIT_SUCCESS ]; then
        fileLogger  "$KO wget file='$file' failed ($rc). Skip checks"
        hasFailed
        taskErr
        continue
    fi
    let iNbTargetOk++

    case $file in
        *.txt)
            bSkipCS=1
            SUCCESS=$EXIT_SUCCESS
            ;;
        *)
            bSkipCS=0
            check_downloaded_file "$file"
            rc=$?
            SUCCESS=$rc
            ;;
    esac

    if [ $SUCCESS -eq $EXIT_SUCCESS ]; then
        archive_downloaded_file "$file"
        rc=$?
        if [ $rc -eq $EXIT_SUCCESS ]; then
            taskOk
        else
            taskErr
        fi
    else
        fileLogger "$WARN no global success for file '$file', so no rename '$day-'"
        taskErr
    fi

done

# Conclusion ##################################################################
#   Now distant log files must be passed in BAK_FILES

### Reporting
taskReportStatus
sReport="$_taskReportLabel DL files"
logStop "$sReport"
reportByMail "$sReport" "$ME"
exit $_iNbTaskErr
