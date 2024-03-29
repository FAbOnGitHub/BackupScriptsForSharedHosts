#!/bin/bash
#
# Author :  FAb Mendes
# Licence : GPL v3
#
#  GOAL :
#   Illustrate plugin concept; Sample to backup a BIG BIG FluxBB instance by:
#    - activating the dump (rake)
#    - copying it outside
#    - reading version of docker image
#    - sending it to XferZone
#
#  REQUIREMENTS:
#   Create a directory for your plugins next to the where "lib.backup.sh" is.
#
#  EXPLANATIONS:
#  Here we just 'tar' some folders with some exclusions. You can do what you
#  want with the same roadmap :
#   1- autoload lib
#   2- declare a new task (taskCount) for reporting-system
#   3- compute an archive name
#   4- make your action to build the archive
#   5- handle errors
#   6- send it to public zone (do_moveXferZone).
#   That's all. Quite simple!
#
#
#  FR:
#   Le but est d'illustrer comment étendre le projet par des scripts plugins.
#   Il faut déposer les plugins dans un dossier parallèle à celui où est
#   "lib.backup.sh"
#
#  Project = FluxBB sauvegarde de grosses tables qui plantent chez OVH
#    - On commence par sauvegarder le schéma et les procédures
#    - Puis pour chacune des tables on essaie d'extraires les données par lots
#      en fonction de l'id entre 2 bornes
#
##############################################################################
###
### START OF AUTOLOAD
###
#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
cd "$(dirname "$0")" || exit 1
CUR_DIR="$PWD";
#Resolving path
cd ..  # one level up
#pwd
# Gottferdom $PWD ne fonctionne pas chez OVH
lib="$(find . -maxdepth 2 -name "lib.backup.sh" 2>/dev/null | head -1)"
if [ "x$lib" = "x" ]; then
    echo "Cannot find lib.backup.sh. Abort" 2>&1
    exit 2
fi
LIB_DIR="$(dirname "$lib")"    # relative dir of lib.backup.sh
#cd - >/dev/null || exit 3  # go back in plugins dir
#pwd
### Load library
cd "$LIB_DIR" 2>/dev/null || exit 4;
export LIB_PATH="$PWD";
#echo "fixing LIB_PATH to $LIB_PATH"
cd - >/dev/null || exit 5 # Ini
if [ ! -f "$LIB_PATH/boot.sh" ]; then
    echo "Cannot find $LIB_PATH/boot.sh" 2>&1
    if [ ! -f cgi-bin/boot.sh ]; then
        echo "Cannot find cgi-bin/boot.sh" 2>&1
        exit 6
    else
        LIB_PATH='cgi-bin'
        .  "$LIB_PATH/boot.sh"
    fi
fi
. "$LIB_PATH/boot.sh"
#cd "$DIR" 2>/dev/null || exit 4;
# where are we ?

### END OF AUTOLOAD
##############################################################################


function at_exit()
{
    ### Reporting
    taskReportStatus
    sReport="$_taskReportLabel backup_many_dir"
    logStop "$sReport"
    reportByMail "$sReport" "$ME"
    exit $_iNbTaskErr
}

function old_main_loop()
{
for TABLE in ${allTables[*]}
do
    req_max="SELECT MAX(id) FROM $TABLE"
    max_id=$(echo $req_max| mysql --defaults-file="$MYSQL_SESAME"|tail -1)
    #max_id=514991

    borne_min=0
    interval=${SQL_DUMP_INTERVAL:-100000}
    borne_max=

    # WHERE id > $borne_min AND id <= $borne_max
    bLoop=1
    while [[ $bLoop -eq 1 ]];
    do
        sWhere=" id > $borne_min "  # 'WHERE' is auto added
        let borne_max=$borne_min+$interval
        if [[ $borne_max -le $max_id ]]; then
            sWhere="$sWhere AND id <= $borne_max"
        else
            bLoop=0
        fi
        debug "$TABLE $borne_min < X < $borne_max (max_id=$max_id) $sWhere"

        dumpBaseTable "$SQL_SERVER1" "$SQL_BASE1" "$SQL_USER1" "$SQL_PASSWD1" \
                      "$TABLE" "$sWhere" "$borne_min"

        borne_min=$borne_max
    done
    ## Concat files into a single .sql
    # "$D_DUMP_FLUX/${base}.table.${table}.${borne}.sql"
    # cat $(ls -1 bornes|sort -n ) > table.sql
    # rm bornes

done
    
}


function dumpBaseTable()
{
    taskCount
    srv="$1"
    base="$2"
    user="$3"
    pass="$4"
    table="$5"
    where="$6"
    borne="$7"

    dumpfile="$D_DUMP_FLUX/${base}.table.${table}.${borne}.sql"
    rm -f "$dumpfile"
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
    if [ "x$table" = "x" ]; then
        fileLogger "$KO $0 : table est vide... abandon"
        hasFailed
        taskErr
        return 1
    fi
    if [ "x$where" = "x" ]; then
        fileLogger "$KO $0 : where est vide... abandon"
        hasFailed
        taskErr
        return 1
    fi
    if [ "x$borne" = "x" ]; then
        fileLogger "$KO $0 : borne est vide... abandon"
        hasFailed
        taskErr
        return 1
    fi

    # #export MYSQL_PWD="$MYSQL_PASS"  #better than '-p$MYSQL_PASS' but not enough
    # # and a file is even better!
    # MYSQL_SESAME=
    # mysql_prepare_connexion "$srv" "$user" "$pass"

    # -n, --no-create-db       Suppress the CREATE DATABASE ...
    # --no-create-info, -t     Don't write table creation info.
    mysql_opt_data="$mysql_opt -t -n -l"

    ## Attention au -n pour pas créer de DB
    mysqldump --defaults-file="$MYSQL_SESAME" $mysql_opt_data \
              "$base" "$table" \
              -w "$where" 1>"$dumpfile" 2>>"$ERR_FILE"
    res=$?
    if [ $res -eq 0 ]; then
        taskOk
        sz="$(du -sh "$dumpfile"  | awk '{print $1 " " $2}')"
        fileLogger "$ok $L_DUMP special table=$table, $borne/$max_id in $base ($sz)"
    else
        taskWarn
        fileLogger "$WARN $L_DUMP failed $srv/$base/$table/$borne (rc=$res)"
        #hasFailed #No it's an option
    fi
}

#
#  Sample of code
#
JOB="flux"
ME=$(basename $0)


##
## Let's play
##
trap at_exit EXIT

radical=${ME%.sh}
D=$(date +"%Y%m%d_%H%M%S")
D_DUMP_FLUX="$BAK_DIR/${radical}_${D}"

mkdir "$D_DUMP_FLUX"


# Bind new variable into old ones
SQL_SERVER1="$SQL_FLUX_SERVER1"
SQL_USER1="$SQL_FLUX_USER1"
SQL_PASSWD1="$SQL_FLUX_PASSWD1"
SQL_BASE1="$SQL_FLUX_BASE1"

# Prepare secure MySQL connexion
MYSQL_SESAME=
mysql_prepare_connexion "$SQL_SERVER1" "$SQL_USER1" "$SQL_PASSWD1"

###
###   Schema and routines
###
taskCount
schemafile="$D_DUMP_FLUX/${SQL_BASE1}.schema.sql"
mysql_opt="$mysql_opt --quick -C --set-charset --comments --dump-date --extended-insert "

mysql_opt_schema="$mysql_opt --routines --triggers"

rm -rf "$schemafile"
mysqldump --defaults-file="$MYSQL_SESAME" $mysql_opt_schema --no-data "$base" \
          1>"$schemafile" 2>>"$ERR_FILE"
res=$?
if [ $res -eq 0 ]; then
    taskOk
    sz="$(du -sh "$schemafile"  | awk '{print $1 " " $2}')"
    fileLogger "$ok $L_DUMP special schema for in $base ($sz)"
else
    taskWarn
    fileLogger "$WARN $L_DUMP failed $srv/$base/schema (rc=$res)"
    #hasFailed #No it's an option
fi

DEBUG=1
##
##  Now looping on each table
##
query="SHOW TABLES;"
declare -a allTables=( $(
                           echo "$query" | mysql \
                                               --defaults-file="$MYSQL_SESAME" \
                                               "$base" \
                               		       | sed -e "1 d" \
		                               | grep -e '^pun_' \
                                                      2>>"$ERR_FILE"
                       ) )

debug "tables filtered = ${allTables[*]}"
echo "tables filtered = ${allTables[*]} MYSQL_SESAME=$MYSQL_SESAME"
for TABLE in ${allTables[*]}
do
    #   req_max="SELECT count(*) FROM $TABLE"
    req_max="SELECT MAX(id) FROM $TABLE"
    max_id=$(echo $req_max| mysql --defaults-file="$MYSQL_SESAME"|tail -1)  
    
#    case $TABLE in
#        pun_config) key=conf_name ;;
#        pun_forums_perm) key='group_id, forum_id' ;;
#        pun_groups) key=g_id ;;
#        pun_online) key=user_id ;;
#        pun_topic_subscriptions) key='user_id, topic_id';;
#        *) key='id';;
#    esac
        

    borne_min=0
    interval=${SQL_DUMP_INTERVAL:-100000}
    borne_max=

    # ORDER BY $key
    # LIMIT $borne_min+1, $borne_max
    bLoop=1
    while [[ $bLoop -eq 1 ]];
    do
        sWhere=" id > $borne_min "  # 'WHERE' is auto added
        let borne_max=$borne_min+$interval
        if [[ $borne_max -le $max_id ]]; then
            sWhere="$sWhere AND id <= $borne_max"
        else
            bLoop=0
        fi
        debug "$TABLE $borne_min < X < $borne_max (max_id=$max_id) $sWhere"

        dumpBaseTable "$SQL_SERVER1" "$SQL_BASE1" "$SQL_USER1" "$SQL_PASSWD1" \
                      "$TABLE" "$sWhere" "$borne_min"

        borne_min=$borne_max
    done
    ## Concat files into a single .sql
    # "$D_DUMP_FLUX/${base}.table.${table}.${borne}.sql"
    # cat $(ls -1 bornes|sort -n ) > table.sql
    # rm bornes

done


####
####  Final step : packaging
####

bMoveXferZoneAutoPurge=0 #debug
bDoCompress=0  # On laisse faire tar

cd "$BAK_DIR" || exit 2
ARCHIVE_FILE="$BAK_DIR/flubb.${SQL_BASE1}.multiparts.tgz"
rm -f "$ARCHIVE_FILE"
tar zcf "$ARCHIVE_FILE" "$D_DUMP_FLUX" 2>>"$ERR_FILE"
rc=$?
if [ $rc -eq 0 ]; then
    szArch="$(du --si -s "$ARCHIVE_FILE" | awk '{print $1}')"
    szDir="$(du --si -s "$d" | awk '{print $1}')"
    fileLogger "$ok $L_DUMP $ARCHIVE_FILE ($szDir->$szArch)"
    do_moveXferZone "$ARCHIVE_FILE"
    rc=$?
    if [ $rc -eq $EXIT_SUCCESS ]; then
        taskOk
    else
        taskErr
    fi
else
    taskErr
    rm -rf "$ARCHIVE_FILE"
    fileLogger "$KO $L_DUMP $ARCHIVE_FILE (rc=$rc)"
fi




# Cleaning
rm -rf "$D_DUMP_FLUX"
mysql_clean_up
### Reporting

taskReportStatus
sReport="$_taskReportLabel backup_many_dir"
logStop "$sReport"
reportByMail "$sReport" "$ME"
exit $_iNbTaskErr


###
# Discussions

#  Attention ces tables n'ont pas de colonnes id :
#  pun_config (conf_name)
#  pun_forums_perm (group_id, forum_id)
#  pun_groups (g_id)
#  pun_online (None, user_id is unique)
#  pun_topic_subscriptions (user_id, topic_id)

#
# On peut récupérer les colonnes auto-incréments avec
# SELECT * FROM sys.`schema_auto_increment_columns` WHERE table_schema = 'test_randolegerforum'
#
# Mais certaines tables n'ont pas ça.
#mysqldump: Couldn't execute 'SELECT /*!40001 SQL_NO_CACHE */ * FROM `poids_backup` WHERE  id > 0 ': Unknown column 'id' in 'where clause' (1054)
#mysqldump: Couldn't execute 'SELECT /*!40001 SQL_NO_CACHE */ * FROM `poids_categories` WHERE  id > 0 ': Unknown column 'id' in 'where clause' (1054)
#mysqldump: Couldn't execute 'SELECT /*!40001 SQL_NO_CACHE */ * FROM `poids_marques` WHERE  id > 0 ': Unknown column 'id' in 'where clause' (1054)
#mysqldump: Couldn't execute 'SELECT /*!40001 SQL_NO_CACHE */ * FROM `poids_mat` WHERE  id > 0 ': Unknown column 'id' in 'where clause' (1054)
#mysqldump: Couldn't execute 'SELECT /*!40001 SQL_NO_CACHE */ * FROM `pun_config` WHERE  id > 0 ': Unknown column 'id' in 'where clause' (1054)
#mysqldump: Couldn't execute 'SELECT /*!40001 SQL_NO_CACHE */ * FROM `pun_forum_perms` WHERE  id > 0 ': Unknown column 'id' in 'where clause' (1054)
#mysqldump: Couldn't execute 'SELECT /*!40001 SQL_NO_CACHE */ * FROM `pun_forum_subscriptions` WHERE  id > 0 ': Unknown column 'id' in 'where clause' (1054)
#mysqldump: Couldn't execute 'SELECT /*!40001 SQL_NO_CACHE */ * FROM `pun_groups` WHERE  id > 0 ': Unknown column 'id' in 'where clause' (1054)
#mysqldump: Couldn't execute 'SELECT /*!40001 SQL_NO_CACHE */ * FROM `pun_online` WHERE  id > 0 ': Unknown column 'id' in 'where clause' (1054)
#mysqldump: Couldn't execute 'SELECT /*!40001 SQL_NO_CACHE */ * FROM `pun_search_matches` WHERE  id > 0 ': Unknown column 'id' in 'where clause' (1054)
#mysqldump: Couldn't execute 'SELECT /*!40001 SQL_NO_CACHE */ * FROM `pun_topic_subscriptions` WHERE  id > 0 ': Unknown column 'id' in 'where clause' (1054)
