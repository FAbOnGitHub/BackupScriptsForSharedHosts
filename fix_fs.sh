#!/bin/bash
##############################################################################
# $Id: fix_fs.sh 96 2012-04-15 21:40:05Z fab $
#
# fix_fs.sh crée avec cs par mendes le 'Wed Jan 13 09:23:26 CET 2010'
#
# Objectif :  Faire de multiples vérifications sur le serveur de RL
#   L'idée est qu'on galère à débugger et certaines opérations comme chmod
#   sont récurrentes.
#   Les chemins sont fixés ici en dur pour ne pas dépendre d'un écrasement.
#   Il faudrait que ce script soit autonome et sûr.
#
# Author: Fabrice Mendes
#
######################################################(FAb)###################
Self=$0
ME=$(basename $Self)
#. functions.sh

LIB_PATH=$(dirname $0)
. $LIB_PATH/boot.sh

###
### 20120415 : oups ! Mais que c'est laid ! Et en plus cela est trop bavard
### sur les autres serveurs. À reprendre. Fixme
D_BACKUP=
case $(hostname -s) in
antaya)
        ROOT=/home/fab/www/Backup
        D_WWW=$ROOT/htdocs
        D_BACKUP=$D_WWW/Backup_DFREvSD
        ;;
herbert)
        ROOT=/home/mendes/www/BackupWeb_80
        D_WWW=$ROOT/www
        ;;

*)
        # OVH
        ROOT=~
        D_WWW=$ROOT/www
        ;;
esac
D_CGIBIN=$ROOT/cgi-bin
D_CGIETC=$ROOT/cgi-etc
D_SECRET=$ROOT/secret
F_SECRET=$D_SECRET/rl.pw
D_WIKI=$D_WWW/wiki

# Config système
#F_LOG=$D_BACKUP/log.txt
#F_ERR=$D_BACKUP/err.txt
F_LOG=$LOG_FILE
F_ERR=$ERR_FILE
D_BACKUP=${D_BACKUP:-$BAK_DIR}

strMsgACorriger='**À corriger !** sinon non ok.'
strLegendMD5="normalement tous les fichiers devraient avoir le même empreinte "
strLegendMD5=$strLegendMD5" si ils protègent de la même manière"
strGenOrDL='Peut-être pas généré et/ou téléchargé'
strCfgHostname='Optionnel : nom calculé à partir du hostname pour permettre encore une conf + souple'

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

say "= Analyse de la configuration et du système de fichier ="
say "*** $ME : starting $(date) ***"
say "Le champ status peut prendre plusieurs valeur. Si c'est en MAJUSCULES c'est"
say "qu'il n'est pas content et qu'il faut regarder."
say "== Vérification de la configuration =="
check_var ROOT WWW_DIR WIKI_DIR
check_var BAK_DIR BAK_DIR_PUB BAK_LEVEL
check_var SQL_SERVER1 SQL_BASE1 SQL_USER1
check_var_secret SQL_PASSWD1
check_var SQL_SERVER2 SQL_BASE2 SQL_USER2
check_var_secret SQL_PASSWD2
check_var_secret ZIP_PASSWD
check_var GPG_KEYFILE
check_var_secret GPG_PASSWD
check_var LOG_FILE ERR_FILE
check_var_URL  BAK_URL
check_var BAK_FILES
check_var BAK_DIR_CLI HTTP_AGENT


say "== Vérification du fichier de log =="
check_file "$F_LOG"
check_writable  "$F_LOG"
say " Si cette étape ne passe pas, on aura aucune trace log du reste."

check_file "$F_ERR"
check_writable  "$F_ERR"


say "== Vérification des commandes de base =="
check_cmd /usr/bin/id
check_cmd /usr/bin/whoami
check_cmd /bin/hostname
check_cmd /usr/bin/mysqldump
check_cmd /usr/bin/zip
check_cmd /usr/bin/cksum
check_cmd /usr/bin/gpg "option"
check_cmd /usr/bin/svnadmin "option"

say "== Variables =="
id="$(id)"
say " HOME='$HOME'"
say " who am i ? $(whoami)"

say "== Arborescence =="
check_dir  "$ROOT"
check_dir  "$D_CGIBIN"
check_dir  "$D_CGIETC"
check_dir  "$D_SECRET"
check_dir  "$D_BACKUP"
check_writable  "$D_BACKUP"
if [ "x$BAK_DIR_CLI" != "x" ]; then
    check_dir  "$BAK_DIR_CLI"
    check_writable  "$BAK_DIR_CLI"
fi
check_dir  "$D_WWW"
check_dir  "$D_WIKI"

say "== Recherche des fichiers de configuration =="
check_file "$D_CGIETC/config_priv.sh" "Optionnel mais vraiment conseillé." "option"
check_file "$D_CGIETC/config_$(/bin/hostname -s).sh" "$strCfgHostname"
check_file "$D_CGIBIN/config_ovh.sh"

say "== Recherche des scripts inclus =="
check_file "$D_CGIBIN/general.sh"
check_file "$D_CGIBIN/boot.sh"
check_file "$D_CGIBIN/$ME"



say "== Analyse correctionnelle des droits sur les scripts =="
# import_backup.sh n'est plus.
for f in backup_sql.sh backup_web.sh import_backup2.sh \
    backup_mysql_full.sh backup_wiki.sh fix_fs.sh
do
    check_cmd "$D_CGIBIN/$f"
    fix_execbit "$D_CGIBIN/$f"
done


say "== Analyse des protections web =="
check_dir_private "$D_SECRET"
check_file "$F_SECRET"
check_dir_private "$D_WWW"
check_dir_private "$D_BACKUP"
check_dir_private "$D_CGIETC"
check_dir_private "$BAK_DIR_CLI"

check_file "$D_CGIETC/dot_htaccess" "Fichier de référence devrait être présent"
for f in "$D_CGIETC/dot_htaccess" "$D_SECRET/.htaccess"\
 "$D_BACKUP/.htaccess" "$D_CGIETC/.htaccess" "$BAK_DIR_CLI/.htaccess"
do
    if [ -f "$f" ];then
        md="$(md5sum "$f")"
        say " $INFO       md5 : $md"
    else
        say " $KO  $f not found"
    fi
done
say " $INFO       légende sur les md5 : $strLegendMD5."

# say "== Recherche des sauvegardes =="
# check_file "$D_BACKUP/www.zip" "$strGenOrDL"
# check_file "$D_BACKUP/randonnerforum1.sql.zip"  "$strGenOrDL"
# check_file "$D_BACKUP/randonner_poids.sql.zip"  "$strGenOrDL"
# check_file "$D_BACKUP/wiki.zip" "$strGenOrDL"

say "== fin =="
exit $EXIT_SUCCESS

##
## Exemple de .htaccess en Apache 2.2
##
AuthUserFile   /home/fab/www/rl.pyrene.homeip.net/secret/rl.pw
AuthGroupFile  /dev/null
AuthName       "Backup RL"
AuthType       Basic
require valid-user
