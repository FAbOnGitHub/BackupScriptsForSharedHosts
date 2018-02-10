#!/bin/bash
#
# Author :  FAb Mendes 
# Licence : GPL v3
#
#  Simple test to fetch env var  in cron scripts
# 

#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
\cd $(dirname $0); DIR=$PWD;
# \cd - >/dev/null;
#Resolving path
cd ..
lib="$(find $PWD/ -maxdepth 2 -name "lib.backup.sh" 2>/dev/null | head -1)"
if [ "x$lib" = "x" ]; then
    echo "Cannot find lib.backup.sh. Abort" 2>&1
    exit 1
fi
DIR="$(dirname $lib)"
cd - >/dev/null

### Load library
cd $DIR 2>/dev/null; export LIB_PATH=$PWD; cd - >/dev/null
. $LIB_PATH/boot.sh


JOB="test_env"
ME=$(basename $0)


report_disk_space
