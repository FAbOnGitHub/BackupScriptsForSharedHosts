#!/bin/bash
# import_backup.sh2  Meo, FAb & RL
#
# Importation mode : test of sending email.
#   In some case the sender is a local user with a not MX-able addresse.
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

TASK_NAME=${TASK_NAME:-"OutThere"}

## URL à afficher dans log, sans le mot de passe
LOG_URL="$(echo "$BAK_URL"|cut -d'@' -f2-)"

# test
update_distant_list
#exit $?

BAK_FILES="doc1.test doc2.test"

# Main loop ###################################################################
declare -a aTmp=( ${BAK_FILES[*]} )
let iNbTargetTotal=${#aTmp[*]}
let iNbTargetOk=0

### Make our own test in relation with import_test.sh
###  Docs.tgz.gpg ?
for raw_file in ${BAK_FILES[*]};
do
    taskCount
    file="$raw_file"
    SUCCESS=$TRUE
    taskOk
    
    fileLogger "Simulation for '$file'"
    let iNbTargetOk++
done

# Conclusion ##################################################################
#   Now distant log files must be passed in BAK_FILES

### Reporting
taskReportStatus
sReport="$_taskReportLabel test import"
logStop "$sReport"
reportByMail "$sReport" "$ME"
exit $_iNbTaskErr
