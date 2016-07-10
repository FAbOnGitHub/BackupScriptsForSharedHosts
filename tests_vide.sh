#!/bin/bash
##############################################################################
# $Id: tests_vide.sh 16 2010-01-12 20:42:54Z fab $
# tests_vide.sh crée avec cs par fab le 'Tue Jan 12 20:37:30 CET 2010'
VERSION=0.0.1
# Objectif :  Vérifier l'étrange histoire du lock.
#
# Author: Fabrice Mendes
# Last Revision :
# - $Revision: 16 $
# - $Author $
# - $Date: 2010-01-12 21:42:54 +0100 (Tue, 12 Jan 2010) $
#
######################################################(FAb)###################


Self=$0
ME=$(basename $Self)
. functions.sh


function help() {
	echo "No help ;-)
$ME [--help|--version]"
}
function print_version() {
    echo "$ME $VERSION"
    exit $EXIT_SUCCESS
}

function  parse_args() {
	#[ "$1" = "" ] && echo "NoArg"
	while [ "$1" ]
	do
	case "$1" in
	 --help) help; exit $EXIT_SUCCESS;
	  ;;
	  --version) echo $VERSION; exit $EXIT_SUCCESS;
	  ;;
	 *) #break 
	    #shift
	  ;;
	 esac
	done 
}

### Main
#parse_args "$@"

if [ -e $NO_SUCH_VARIABLE ];then
    echo "(-e) Ohhh le lock est présent sans variable : PAS BIEN"
else
    echo "(-e) le lock a l'air de ne pas exister."
fi
if [ -f $NO_SUCH_VARIABLE ];then
    echo "(-f) Ohhh le lock est présent sans variable : PAS BIEN"
else
    echo "(-f) le lock a l'air de ne pas exister."
fi



exit $EXIT_SUCCESS

