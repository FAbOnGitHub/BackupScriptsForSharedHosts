#!/bin/bash
##############################################################################
# $Id$
# diff_config crée avec cs par mendes le '2016-11-04 09:54:31'
VERSION=0.0.1
# Objectif :
#   Comparer des fichiers de configurations pour faciliter l'évolution
#   de ces fichiers (ajouts d'options)
#
# Author: Fabrice Mendes
# Last Revision :
#
######################################################(FAb)###################
ME=$0
#DEBUG=1
#echo "1 [DEBUG=$DEBUG]"

#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
\cd "$(dirname $0)"; LIB_PATH="$PWD"; \cd - >/dev/null;
. $LIB_PATH/boot.sh


function help()
{
	[ "x$1" != "x" ] && status=$1 || status=$EXIT_FAILURE
	echo "
$ME [--help|--version]
$ME [-V] conffile1 [conffile2]
  -V : diff only variables, without their values
  'ovh_config.sh' is the default for conffile2
 "
	exit  $status

}
function print_version()
{
    revision='$Revision$'
    tag=Revision
    [ "$revision" = "$"$tag"$" ] && rev="" || rev="($revision)"
    echo "$ME $VERSION $rev"
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
	  --version) print_version
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

function prepareDiff()
{
    local f="$1"
    F="$(basename $f)"
    if [ $bWithoutValues -eq 0 ]; then
        sed -e "s@\(#.*$\)@@" -e "/^$/ d " "$1" |sort > "$D_TMP/$F"
    else
        sed -e "s@\(#.*$\)@@" -e "s@\(.*=\)\(.*\)@\1@" -e "/^$/ d " "$1" \
            |sort > "$D_TMP/$F"
    fi
}

### Main
#parse_args "$@"

#echo "2 [DEBUG=$DEBUG]"

bWithoutValues=0
if [ "x$1" = "x-V" ]; then
    echo "Diff without values"
    bWithoutValues=1
    shift
fi

file1="$1"
file2="$2"

if [ "x$file1" = "x" ]; then
    error "Missing conffile1"
    help
    exit 2
fi
if [ "x$file2" = "x" ]; then
    file2="$LIB_PATH/config_default.sh"
fi

if [ ! -f "$file1" ]; then
    die "'$file1' not found"
fi
if [ ! -f "$file2" ]; then
    die "'$file2' not found"
fi

D_TMP=/tmp/$ME  
mkdir -p "$D_TMP"
chmod 700 "$D_TMP"

F1="$(basename "$file1")"
F2="$(basename "$file2")"

prepareDiff "$file1"
prepareDiff "$file2"

diff "$D_TMP/$F1" "$D_TMP/$F2"

echo "rm -rf $D_TMP"
# see to use rc=$? and then exit $rc
exit $EXIT_SUCCESS
