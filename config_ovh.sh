# config_ovh.sh
#  Initial author : Meo pour RL
#  Main dev : FAb
#
#  Licence  GPL v3
#
# Configuration serveur OVH
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

#
# DEBUG:  0=rien, 1=log fichier, 2=log fichier + écran
# Penser à le redéfinir dans le fichier privé
DEBUG=${DEBUG:-0} # 0 par défaut mais peut être changé dans la ligne de commande
                  # pour tester

#
# TASK_NAME : identifiant d'une opération, par exemple le nom du serveur qui est
# 	en cours de copie. Utilisé pour calculé le nom des logs du serveur vers
#	le local. À écraser dans config_xxxx_dist.sh
TASK_NAME="serveur"

##
## Partie serveur, pour les scripts de sauvegarde locale
##
SQL_SERVER1=mysql5-2.bdb	# Serveur SQL
SQL_BASE1=randonnerforum1	# Base SQL 1
SQL_USER1=randonnerforum1	# Login SQL 1
SQL_TABLES1=pun_search_matches	# ou des tables à traiter à part
SQL_SERVER2=mysql5-5          	# Serveur SQL
SQL_BASE2=randonner_poids     	# Base SQL 2
SQL_USER2=randonner_poids     	# Login SQL 2
WWW_DIR=~/www                 	# Racine web
BAK_DIR=$WWW_DIR/backup_LH5Y59v	# Dossier de backup
WIKI_DIR=$WWW_DIR/wiki/data/	# Racine wiki
UPLOAD_DIR=$WWW_DIR/forum/uploads # les uploads bannis
LOCK_FILE=$BAK_DIR/rl.lock	# Lock, ne pas déclarer cette variable est dangereux.
LOG_FILE=$BAK_DIR/log.txt       # Journal
ERR_FILE=$BAK_DIR/err.txt       # Journal des erreurs système
# Les logs devraient être de la forme $BAK_DIR/$(hostname -s).log.txt

# Ces variables sont définies (écrasées) dans un fichier
# dont le nom dépend de l'hôte dans le répertoire ../cgi-etc/
SQL_PASSWD1=			# Mot de passe SQL 1
SQL_PASSWD2=                  	# Mot de passe SQL 2
ZIP_PASSWD=                   	# Mot de passe zip

MYSQL_USER=		      	# Utilisateur pour le dump complet
MYSQL_PASS=

GPG_KEYFILE=			# Fichier clé publique
GPG_PASSWD=			# sinon un mdp pr chiffrement symétrique

# Exclure les tables commençant par ce préfixe dans backup_mysql_full.sh
MYSQL_DB_EXCLUDE_PREFIX=test_	# Eclure les BDD de test
MYSQL_DB_EXCLUDE_PREFIX=	# reset



##
## Mail settings
## 
bUseMailWarning=0		# Désactive la notificatin par email
bUseMailWarning=1		# Active la notificatin par email
NOTIFY_SUBJECT="Errors occured, please inspect log='%LOG_FILE'"
NOTIFY_TO="admin1@your_domain.tld admin2@your_domain.tld"
NOTIFY_FROM='you@your_domain.tld'

##
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
#
# Liste archives
BAK_FILES="www.zip  wiki.zip $SQL_BASE1.sql.zip $SQL_BASE2.sql.zip"
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

# Authorise le téléchargement de fichiers supplémentaires à la demande du
# serveur. Voir fichier general.sh
bUseDistantBakFile=1
sDistantBakFilename="Please_backup.lst"
