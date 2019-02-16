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

ME=$0

#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
\cd "$(dirname $0)"; LIB_PATH="$PWD"; \cd - >/dev/null;
. $LIB_PATH/boot.sh


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

    rm -f "$BAK_DIR/$base".sql*
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
    #export MYSQL_PWD="$MYSQL_PASS"  #better than '-p$MYSQL_PASS' but not enough
    MYSQL_SESAME=
    mysql_prepare_connexion "$srv" "$user" "$pass"

    
    #export MYSQL_PWD="$pass"

    if [ "x$5" != "x" ]; then
        # Présence de table à exclure ou traiter séparément
        shift; shift; shift; shift; #drop $1 $2 $3 $4 for $@
        for table in $@
        do
            taskCount
            # On cumule une liste d'exclusion, on essaie de dumper ces tables d'abord.
            exclude="$exclude --ignore-table=${base}.${table}"
            name=${base}.${table}
            ## Attention au -n pour pas créer de DB
            mysqldump --defaults-file="$MYSQL_SESAME" "$mysql_opt" -l -n "$base" "$table" \
                1>"$BAK_DIR/${name}.sql" 2>>"$ERR_FILE"
            res=$?
            if [ $res -eq 0 ]; then
                taskOk
                sz="$(du -sh "$$BAK_DIR/${name}.sql")"
                fileLogger "$ok $L_DUMP special table=$table in $base ($sz)"
                do_moveXferZone "$BAK_DIR/${name}.sql"
            else
                taskWarn
                fileLogger "$WARN $L_DUMP failed $srv/$base/$table (rc=$res)"
                #hasFailed #No it's an option
            fi
        done

    fi

    # Finalement on essaie de dumper tout le reste de le BDD 
    # bug ! Fallait pas le -B
    mysqldump --defaults-file="$MYSQL_SESAME" "$mysql_opt" "$exclude" -l "$base" \
        1>"$BAK_DIR/$base.sql" 2>>"$ERR_FILE"
    res=$?
    if [ $res -eq 0 ]; then
        taskOk
        sz="$(du -sh "$$BAK_DIR/${base}.sql")"
        fileLogger "$ok $L_DUMP $base (other tables, $sz)"
        do_moveXferZone "$BAK_DIR/$base.sql"
    else
        fileLogger "$KO $L_DUMP $srv all $base (rc=$res) $exclude"
        taskErr
        hasFailed
    fi
}

#######
# Main
########

cd "$BAK_DIR"

#debug "dumpBase $SQL_SERVER1,$SQL_BASE1,$SQL_USER1,$SQL_PASSWD1"
#dumpBase $SQL_SERVER1 $SQL_BASE1 $SQL_USER1 $SQL_PASSWD1 $SQL_TABLES1

mysql_opt="--routines --triggers --comments --dump-date --extended-insert "
mysql_opt="$mysql_opt --quick -C --set-charset"

for i in $(seq 1 32);
do
    name="SQL_SERVER$i"
    sql_serverI=${!name}

    if [ "x$sql_serverI" = "x" ]; then
        # $ok vs $info: je préfère $ok c'est plus simple pour lire les mails
        fileLogger "$ok $L_DUMP no more dabase as $name. Stop"
        break
    fi
    name="SQL_BASE$i"
    sql_baseI=${!name}
    name="SQL_USER$i"
    sql_userI=${!name}
    name="SQL_PASSWD$i"
    sql_passwdI=${!name}
    name="SQL_TABLES$i"
    sql_tablesI=${!name}   
    debug "dumpBase $SQL_SERVER1,$SQL_BASE1,$SQL_USER1,$SQL_PASSWD1"
    dumpBase "$sql_serverI" "$sql_baseI" "$sql_userI" "$sql_passwdI" "$sql_tablesI"

done

    
mysql_clean_up
taskReportStatus
sReport="$_taskReportLabel DB saved (by $ME)"
logStop "$sReport"
# FIXME : there is a new way to do this. (added to force a git push)
if [ $bUseMailWarning -eq 1 ]; then
    view_today_logs| notify_email_stdin "$sReport"
fi

#exit $_iNbTaskErr
mainExit $_iNbTaskErr
