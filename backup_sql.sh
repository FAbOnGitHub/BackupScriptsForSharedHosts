#!/bin/bash

# backup_sql.sh
#  Initial author : Meo for RL
#  Main dev : FAb
# 
#
# Spécifique à l'association : 
# Sauvegarde, compresse et crypte les 2 bases MySQL de RL.
#
# Program author :
#  - Intial programmer : Meo
#  - Main programmer : faydc (fab)
#
# Revision :
# -$Author: fab $
# -$Date: 2016-05-29 22:32:19 +0200 (Sun, 29 May 2016) $
# -$Revision: 150 $
#
# Licence : GPL v3

#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
DIR=$(dirname $0) #Resolving path
cd $DIR 2>/dev/null; export LIB_PATH=$PWD; cd - >/dev/null
. $LIB_PATH/boot.sh


ME=$0

GENERAL_SUCCESS=$EXIT_SUCCESS

# dumpBase $serveur $base $user $passwd $*
#          $1       $2    $3    $4	le reste
#
# L'option mysqldump -l (lock-tables) garantit l'intégrité des bases (l'idéal
# étant de désactiver l'accès au site lors du backup).
# Ajout de l'option --ignore-table=database.table pour sauvegarder le forum
#          malgré la taille immense de table punsearch.
#
function dumpBase()
{
    taskCount
    srv=$1
    base=$2
    user=$3
    pass=$4
    exclude=''

    rm -f $BAK_DIR/$base.sql*
    if [ "x$srv" = "x" ]; then
        fileLogger "$KO $0 : pas de serveur indiqué... abandon"
        taskErr
        hasFailed
        return 1
    fi
    if [ "x$base" = "x" ]; then
        fileLogger "$KO $0 : pas de base SQL indiquée... abandon"
        hasFailed
        taskErr
        return 1
    fi
    if [ "x$user" = "x" ]; then
        fileLogger "$KO $0 : user vide... abandon"
        hasFailed
        taskErr
        return 1
    fi
    if [ "x$pass" = "x" ]; then
        fileLogger "$KO $0 : passwd est vide... abandon"
        hasFailed
        taskErr
        return 1
    fi
    export MYSQL_PWD="$pass"
    
    if [ "x$5" != "x" ]; then
        shift; shift; shift; shift; #drop $1 $2 $3 $4 for $@
        for table in $@
        do
            exclude="$exclude --ignore-table=${base}.${table}"
            name=${base}.${table}
            ## Attention au -n pour pas créer de DB
            mysqldump -h $srv -u $user -l -n $base $table \
                1>"$BAK_DIR/${name}.sql" 2>>$ERR_FILE
            res=$?
            if [ $res -eq 0 ]; then
                taskOk
                fileLogger "$ok $L_DUMP $base $table"
                do_moveXferZone "$BAK_DIR/${name}.sql"
            else
                taskWarn
                fileLogger "$WARN $L_DUMP $srv/$base/$table (rc=$res)"
                #hasFailed #No it's an option
            fi
        done

    fi

    # bug ! Fallait pas le -B
    mysqldump -h $srv -u $user $exclude -l $base \
        1>$BAK_DIR/$base.sql 2>>$ERR_FILE
    res=$?
    if [ $res -eq 0 ]; then
        taskOk
        fileLogger "$ok $L_DUMP $base $table"
        do_moveXferZone "$BAK_DIR/$base.sql"
    else
        fileLogger "$KO $L_DUMP $srv/$base/$table (rc=$res)"
        taskErr
        hasFailed
    fi
}

#######
# Main
########

cd $BAK_DIR
debug "dumpBase $SQL_SERVER1,$SQL_BASE1,$SQL_USER1,$SQL_PASSWD1"
dumpBase $SQL_SERVER1 $SQL_BASE1 $SQL_USER1 $SQL_PASSWD1 $SQL_TABLES1



# 2016-05-29 Sur la demande d'olivier
#debug "dumpBase $SQL_SERVER2,$SQL_BASE2,$SQL_USER2,$SQL_PASSWD2"
#dumpBase $SQL_SERVER2 $SQL_BASE2 $SQL_USER2 $SQL_PASSWD2


taskReportStatus
sReport="$_taskReportLabel DB saved (by $ME)"
logStop "$sReport"
if [ $bUseMailWarning -eq 1 ]; then
    view_today_logs| notify_email_stdin "$sReport"
fi
exit $_iNbTaskErr
