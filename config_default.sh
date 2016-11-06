# config_default.sh
#  Initial author : Meo pour RL
#  Main dev : FAb
#
#  Licence  GPL v3
#


# EN:
#
# Configuration server
#
# - config_default.sh :
#         all configuration variables
# - ../cgi-etc/config_priv.sh :
#         specific to an host
# - ../cgi-etc/config_<hostname>.sh
#         Idem
#         hostname = $(hostname -s)
#      


# FR:
#
# Ce fichier constitue la configuration général des scripts de backup de RL. Ce
# fichier doit leur permettre de fonctionner à l'exception des informations
# sensibles comme les mots de passe.
# Pour ces derniers il conviendra d'utiliser le fichier privé :
# ../cgi-etc/config_priv.sh
# Pour les développeurs, un second fichier est chargé en suite :
# ../cgi-etc/config_<hostname>.sh
# Même rôle mais n'est appelé qu'en fonction du nom d'hôte.
#
# Dans ce fichier dit privé on pourra éventuellement changer n'importe quelle
# variable ci-dessous.
#

###############################################
## General options
###############################################

#
# DEBUG:  0=nothing, 1=log file, 2=log file and stdout
#   can be overwritten from CLI during test/debug sessions
DEBUG=${DEBUG:-0}
#FR:  Penser à le redéfinir dans le fichier privé
#FR:  0 par défaut mais peut être changé dans la ligne de commande pour tester
#FR:  0=rien, 1=log fichier, 2=log fichier + écran

# EN : Task Id
# FR:
# TASK_NAME : identifiant d'une opération, par exemple le nom du serveur qui est
# 	en cours de copie. Utilisé pour calculé le nom des logs du serveur vers
#	le local. À écraser dans config_xxxx_dist.sh
TASK_NAME="serveur"
# This one is used by mail notification
PRJ="B4SH"


##
# root of the web server
WWW_DIR=~/www
#FR: Racine web

##
# Where archives are store on the server
# See BAK_DIR_CLI 
BAK_DIR=$WWW_DIR/backup_LH5Y59v
#FR: Dossier de backup


##
#  Lock file to prevent multi-backup
LOCK_FILE=$BAK_DIR/rl.lock
#FR : fichier verrour pour éviter les sauvegardes concurrentielles
# Lock, ne pas déclarer cette variable est dangereux.

##
# Differents logs file
LOG_FILE=$BAK_DIR/log.txt       # Journal
ERR_FILE=$BAK_DIR/err.txt       # Journal des erreurs système
#FR: Les logs devraient être de la forme $BAK_DIR/$(hostname -s).log.txt


###############################################
## Server option
###############################################

## #######################################
##  Archives  (compression and cypher)
## #######################################

# Use compression
bDoCompress=${bDoCompress:-1}
bDoCompressAll=${bDoCompressAll:-1}
#FR: utilise la compression de fichier

# Zip Archives password
ZIP_PASSWD=
#FR: Mot de passe zip

# Utilise le chiffrement
bDoCypher=${bDoCypher:-0}
bDoXfer=${bDoXfer:-0}
# Compression program
sCompressProg=/bin/gzip
# Arguments for compression program
sCompressArgs='-9'
# Program used to cypher data
sCypherProg=/usr/bin/gpg2
# arguments
sCypherArgs="--batch "

##
# GnuPG credentials
GPG_KEYFILE=			# Fichier clé publique
GPG_PASSWD=			# sinon un mdp pr chiffrement symétrique



## #######################################
## Mail settings
## #######################################

# 1: use mail notification, 0 else
bUseMailWarning=0
#FR:  Désactive la notificatin par email
bUseMailWarning=1
#FR:  Active la notificatin par email

# 'mail' command is avaible (else the program must handle it)
bMailCommandAvaible=1
#FR: Peut indiquer que la commande mail n'est pas disponible

# Subject field in mails
NOTIFY_SUBJECT="Errors occured, please inspect log='%LOG_FILE'"
#FR: le sujet des messages

# Who will be notified by mail 
NOTIFY_TO="admin1@your_domain.tld admin2@your_domain.tld"
#FR:  Destinataires des messages

# From field
NOTIFY_FROM='you@your_domain.tld'
#FR: expéditeur des messages



####################
## backup_wiki.sh
####################

##
# Data of the dokuwiki : 
WIKI_DIR=$WWW_DIR/wiki/data/
#FR: Racine wiki

####################
## backup_web.sh
####################

##
# Excluded part of the forum
UPLOAD_DIR=$WWW_DIR/forum/uploads
#FR: sous dossier uploads banni



#######################
## backup_mysql_full.sh
#######################

MYSQL_HOST=localhost #Change me
#MYSQL_OPT="--skip-events --skip-lock-tables"
MYSQL_OPT="--events --routines --triggers -l"

##
#  Global MySQL credentials
MYSQL_USER=		      	# Utilisateur pour le dump complet
MYSQL_PASS=
## 
# Prefix to exclude some table in a sql dump
#FR: Exclure les tables commençant par ce préfixe dans backup_mysql_full.sh
MYSQL_DB_EXCLUDE_PREFIX=test_	# Eclure les BDD de test
MYSQL_DB_EXCLUDE_PREFIX=	# reset





###############################################
## import_backup2.sh              (aka client)
###############################################

## EN:
## On a second host, this program is called to fetch the archives and store
## them locally day by day except on LTS_PATTERN

## FR:
## Partie sur un client distant, permet de fonctionner même
## si on oublie le fichier hôte
#
# Normalement ces variables devraient être dans le fichier privé
# Elles ne sont utilisés que par les scripts "distants" qui viennent
# chercher des données comme import_backup2.sh
# Le client peut redéfinir les variables de chemin précédentes au cas où il ne
# serait pas installé de la même manière

# URL dossier backup distant
BAK_URL=https://login:password@you_domain.tld/backup_SecretToken
URL_USER="mylogin"
URL_PASS="MySecretPassword"
BAK_URL="http://${URL_USER}:${URL_PASS}@domain.tld/Token"
# Liste archives
TARGET_SRV=antaya

#
# Liste archives
BAK_FILES="www.zip  wiki.zip"
BAK_FILES="$BAK_FILES $SQL_BASE1.sql.zip"
BAK_FILES="$BAK_FILES $SQL_BASE2.sql.zip"

# BAK pour le client
BAK_DIR_CLI=$BAK_DIR
# LTS_DIR : Sert de répertoire de dépôt (par import_backup2.sh) de longue durée
# pour les cas où aucun admin ne serait disponible pendant une longue
# durée. Comme les dumps tournent sur une semaine et finissent par être écrasés
# il est sécurisant de pouvoir revenir plus loin en arrière.
LTS_DIR="$BAK_DIR_CLI/LTS"
# Motif de la date à laquelle on copie les archives dans le dossier LTS_DIR
# Par défaut le jeudi semble un bon cheval, la veille du WE (absence des
# randonneurs, risques supérieur de Hack)(De 1-Mon à 7-Sun)
LTS_PATTERN="4-Thu"
# level
BAK_LEVEL=10
# Niveaux d'archivage
HTTP_AGENT=nobody

##
# Shall we let distant server to add some files to download ?
bUseDistantBakFile=1
#FR: Authorise le téléchargement de fichiers supplémentaires à la demande du
#FR:  serveur. Voir fichier general.sh

# Which is the file which contains the list of the archives to retrieve ?
sDistantBakFilename="Please_backup.lst"
#FR: Fichier contenant la liste des archives supplémentaires à récupérer

#########################
## backup_sql.sh
#########################
## Really specific : backup some tables from some databases
# FR: sauvegarde certaines tables et bases (à une époque une table trop
#     volumineuse posait des problèmes de sauvegarde)
SQL_SERVER1=server1f.fqdn	# Serveur SQL
SQL_BASE1=base1			# Base SQL 1
SQL_USER1=user1			# Login SQL 1
SQL_TABLES1=excluded_tables	# ou des tables à traiter à part
SQL_SERVER2=sql.server2.fqdn 	# Serveur SQL
SQL_BASE2=base2		     	# Base SQL 2
SQL_USER2=user2		     	# Login SQL 2
SQL_PASSWD1=			# Mot de passe SQL 1
SQL_PASSWD2=                  	# Mot de passe SQL 2
