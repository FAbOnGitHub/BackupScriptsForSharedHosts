#!/bin/bash
##############################################################################
# $Id$
# test_mail.sh crée avec cs par fab le '2017-01-14 15:27:42'
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


taskCount
taskOk

### Reporting
taskReportStatus
sReport="$_taskReportLabel test mail"
logStop "$sReport"
reportByMail "$sReport" "$ME"

# see to use rc=$? and then exit $rc
exit $EXIT_SUCCESS

