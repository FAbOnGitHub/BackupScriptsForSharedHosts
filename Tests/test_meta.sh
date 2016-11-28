#!/bin/bash
##############################################################################
# $Id$
# test_meta.sh crée avec cs par mendes le '2016-11-16 13:44:28'
VERSION=0.0.1
# Objectif : 
#
# Author: Fabrice Mendes
# Last Revision :
# - $Revision$
# - $Author$
# - $Date$
#
######################################################(FAb)###################


ME=$0
#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
#Resolving path but in this script is in 'Tests'
\cd $(dirname $0)/..; DIR=$PWD; \cd - >/dev/null;

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

### Main
#parse_args "$@"
f=test1.zip.gpg.meta
let max=3600*30

readMetaData $f
d1=1259100187
d1=1479100187
d2=$epochFile
d3=$(date +"%s")

csum1=$csumFile
size1=$sizeFile
epoch1=$epochFile
date1="$dateFile"



t1=$d3
t2=$d1
s1="$(date --date "@""$t1" +"%F %T")"
s2="$(date --date "@""$t2" +"%F %T")"
#set -x
dateDiff -s "@$t1" "@$t2"
set +x
delta=$dateDelta
echo "d1=$t1 $s1"
echo "d2=$t2 $s2"
echo "delta=$dateDelta et max=$max"
if [ $delta -gt $max ]; then
    sMsg="danger delta=$delta > max=$max"
    echo $sMsg
    error $sMsg
fi

csumFile="x"
sizeFile='x'
dateFile='never'
epochFile="y"

readMetaDataOldWay "$f"
rc=$?
if [ $rc -ne $EXIT_SUCCESS ]; then
    error "readMetaDataOldWay failed rc=$rc"
    exit $rc
fi
csum2=$csumFile
size2=$sizeFile
epoch2=$epochFile
date2="$dateFile"
dd3=$(date +"%s")

echo -e " size   \t csum   \t date"
echo -e "${size1} \t${csum1} \t${date1}"
echo -e "${size2} \t${csum2} \t${date2}"

if [ "$csum1"="$csum2" -a "$size1"="$size2" -a "$date1"="$date2" ]; then
    echo "Ok same values"
    rc=$EXIT_SUCCESS
else
    echo "Error"
    rc=$EXIT_FAILURE
fi

logStop
# see to use rc=$? and then exit $rc
exit $rc

