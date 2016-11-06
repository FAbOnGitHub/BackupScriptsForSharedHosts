# $Id: boot.sh 123 2014-03-29 10:08:07Z fab $
# Chargement commun des fonctions et des configurations avec l'idée
# de pouvoir faire un zip des scripts + config minimal (OVH) qui puisse
# être transmise brutalement et dézippé sur le serveur.
#
# Revision :
# -$Author: fab $
# -$Date: 2014-03-29 11:08:07 +0100 (Sat, 29 Mar 2014) $
# -$Revision: 123 $


## Penser à inclure ces trois lignes dans tous les scripts
##  (À INCLURE) Chemin fichiers inclus, auto-ajustement
#LIB_PATH=$(dirname $0)
# . $LIB_PATH/boot.sh

export EXIT_SUCCESS=0
export EXIT_FAILURE=1
ok='[__ok__]'
KO='[**KO**]'
NOTFOUND='[NOTFND]'
NOTEXEC='[NOTEXE]'
INFO='[__..__]'
INFO='[ info ]'
WARN='[=WARN=]'
t2='=='
t3='==='
t4='==='
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
export ok KO NTFOUND INFO WARN t2 t3 t4
export DEBUG VERBOSE

### Variables:
# BAK_DIR :	répertoire où sont fabriquées les archives
# BAK_DIR_PUB :	répertoire où le serveur dépose les archives pour le client
# BAK_DIR_CLI :	répertoire où le client va chercher les archives sur le serveur distant

ME=$(basename $0)
# Chargement des fonctions générales
msg="Loading $LIB_PATH/general.sh"
. $LIB_PATH/general.sh

# Chargement de la config par défaut (OVH), serveur de prod
msg=$msg"\nloading $LIB_PATH/config_ovh.sh"
. $LIB_PATH/config_ovh.sh


## Chargement éventuel d'une config alternative par machine
## On peut écraser toutes les valeurs
#  Finalement ce n'est pas une si bonne idée car sur OVH le
#  hostname varie... Donc je fixe un nom à config_priv comme
#  privée
export D_ETC="$(echo $LIB_PATH | sed -e "s@\/cgi-bin\$@\/cgi-etc@" )"
if [ ! -d "$D_ETC" ]; then
    die "Cannot find \$D_ETC from \$LIB_PATH=$LIB_PATH"
fi
f=$D_ETC/config_priv.sh
if [ -f "$f" ]; then
    msg=$msg"\nloading config_priv.sh"
    . "$f"
else
    debug "Cannot find $f"
fi
#
#  Mais pour les machines des copains on peut encore redéfinir
#  les variables tranquillou
hostname=$(hostname -s)
f="$D_ETC/config_${hostname}.sh"
if [ -f "$f" ]; then
    msg=$msg"\nloading config_${hostname}.sh"
    . "$f"
fi

#
#  Localement à ce serveur, il y a deux types de scripts. Ceux qui s'occupent
#  que de sauvegarder les données sur lui même (dits scripts locaux) et ceux qui
#  servent à répliquer une machine (dits scritps distants). Ces derniers ont une
#  possibilité de configuration par le fichier ci-dessous.
#  FAb: sur mon serveur les BD sont différents donc ces 2 sortent de scripts
#  doivent pouvoir utiliser des jeux différents de données.
#
ME=$(basename $0)
case $ME in
    backup_*)
        msg=$msg"\nLocal script skip bonus"
        ;;
    *)
        msg=$msg"\nDist script... bonus !"
        cfg_dist="$D_ETC/config_${hostname}_dist.sh"
        #echo "cfg_dist=$cfg_dist"
        if [ -f "$cfg_dist" ]; then
            msg=$msg"\nloading $cfg_dist"
            . "$cfg_dist"
        else
            msg=$msg"\nno '$cfg_dist' found"
        fi
        ;;
esac
debug "$msg"

if [ "x$BAK_DIR_PUB" = "x" ]; then
    fileLogger "BAK_DIR_PUB not defined: set to BAK_DIR=$BAK_DIR"
    #echo "BAK_DIR_PUB not defined: set to BAK_DIR=$BAK_DIR"
    BAK_DIR_PUB=$BAK_DIR
fi
mkdir -p $BAK_DIR $LTS_DIR $BAK_DIR_PUB

if [ "x$LOG_FILE" = "x" ]; then
    export LOG_FILE=/tmp/scripts_RL.txt
    echo "LOG_FILE not set, using default $LOG_FILE"
fi
if [ "x$ERR_FILE" = "x" ]; then
    export ERR_FILE=$LOG_FILE
    date > $ERR_FILE
    chmod o-rwx $ERR_FILE
fi
if [ ! -f "$LOG_FILE" ]; then
    date > $LOG_FILE
    chmod o-rwx $LOG_FILE
fi
if [ ! -f "$ERR_FILE" ]; then
    date > $ERR_FILE
    chmod o-rwx $ERR_FILE
fi
if [ "x$ZIP_PASSWD" = "x" ]; then
    fileLogger "ZIP_PASSWD is not defined... default value"
    ZIP_PASSWD="NeverForgetToSetAPassowrd"
fi

if [ "x$BAK_DIR_PUB" = "x" ]; then
    fileLogger "BAK_DIR_PUB is not defined... set to \$BAK_DIR"
    BAK_DIR_PUB=$BAK_DIR
fi


function viewConfig()
{
    say " viewConfig"
    check_dir $BAK_DIR "BAK_DIR"
    check_file $LOCK_FILE  "[LOCK_FILE=$LOCK_FILE]"
    check_dir $LTS_DIR "LTS_DIR"
    check_file $LOG_FILE "LOG_FILE"
    check_file $ERR_FILE "ERR_FILE"
#    echo "[=]"
    echo "[DEBUG=$DEBUG]"

}

 if  [ "$ME" != "fix_fs.sh" ]; then
     if [ $DEBUG -ne 0 ]; then
         viewConfig
     fi
 fi

