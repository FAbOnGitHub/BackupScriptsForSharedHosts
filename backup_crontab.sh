#!/bin/bash
##############################################################################
# backup_crontab.sh crée avec cs par fab le '2012-03-27 11:47:37'
#
# Objectif : Sauvegarder les crontabs, la liste des travaux planifiés
#  car parfois on oublie qu'on a mis à tourner.
#  Ce script est lié à ceux du projet RL.
#
# Author: Fabrice Mendes
#
# Licence : GPL v3
#
######################################################(FAb)###################

ME=$0
#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
DIR=$(dirname $0) #Resolving path
cd $DIR 2>/dev/null; export LIB_PATH=$PWD; cd - >/dev/null
. $LIB_PATH/boot.sh


function help()
{
	[ "x$1" != "x" ] && status=$1 || status=$EXIT_FAILURE
	echo "No help ;-)
$ME [--help|--version]"
	exit  $status

}
function print_version()
{
    echo "$ME $VERSION"
    exit $EXIT_SUCCESS
}

# Fonction appelée par le bash pour la completion magique
# dont la déclaration se fait dans le .bashrc
# Convention purement personnelle.
function auto_complete()
{
    echo "<change me>"
}

function  parse_args()
{
	#[ "$1" = "" ] && echo "NoArg"
	while [ "$1" ]
	do
	case "$1" in
	 -h|--help) help; exit $EXIT_SUCCESS;
	  ;;
	  --version) echo $VERSION; exit $EXIT_SUCCESS;
	  ;;
	--auto-complete)
	auto_complete
	exit $EXIT_SUCCESS
	;;
	 *) #break
	    #shift
	  ;;
	 esac
	done
}

### Main
#parse_args "$@"
Self=$(basename $ME)
U=$(whoami)
H=$(hostname -s)
dumpfile=$H.crontab.$U.dump
taskCount

fileLogger "$Self : starting"

cd $BAK_DIR
crontab -l > $dumpfile 2>>$ERR_FILE
rc=$?
if [ $rc -eq $EXIT_SUCCESS ]; then
    fileLogger "$ok $L_DUMP $dumpfile (rc:$rc)"
    do_moveXferZone "$dumpfile"
    rc=$?
    if [ $rc -eq $EXIT_SUCCESS ]; then
        taskOk
    else
        taskErr
    fi
else
    taskErr
    fileLogger "$KO $L_DUMP $dumpfile (rc:$rc)"
fi

### Reporting
taskReportStatus
sReport="$_taskReportLabel crontab"
logStop "$sReport"
reportByMail "$sReport" "$ME"
exit $_iNbTaskErr
