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
export TRUE=1
export FALSE=0
ok='[__ok__]'
KO='[**KO**]'
NOTFOUND='[NOTFND]'
NOTEXEC='[NOTEXE]'
INFO='[__..__]'
INFO='[ info ]'
WARN='[=WARN=]'
ERRO='[ERROR!]'
t2='=='
t3='==='
t4='==='
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
export ok KO NTFOUND INFO WARN t2 t3 t4
export DEBUG VERBOSE

# Labels for tasks :
L_WGET="_WGET_____"
L_DUMP="_DUMP_____"
L_COMPRESS="_COMPRESS_"
L_CYPHER="_CYPHER___"
L_OFFER="_OFFER____"
L_MAIL="_MAIL_____"
L_ARCH="_ARCH_____"
L_LTS="_ARCH+LTS_"
L_PARSELOG="_SCAN_LOG_"
L_CHECKMETA="_CHK_META_"
L_CHECKDISK="_CHK_DISK_"
export L_WGET L_DUMP L_COMPRESS L_CYPHER L_OFFER L_MAIL L_ARCH L_LTS
export L_CHECKMETA

# bugs ignorable
BUG_IGNORE=1
BUG_REPORT=2
BUG_WARN=4

### Variables:
# BAK_DIR     :	dossier où sont fabriquées les archives
# BAK_DIR_PUB :	dossier où le serveur dépose les archives pour le client
# BAK_DIR_CLI :	dossier où le client dépose les archives récupérées sur le serveur 
# LTS_DIR     : dossier jamais effacé automatiquement

ME=$(basename $0)
# Chargement des fonctions générales
msg="Loading $LIB_PATH/general.sh"
. $LIB_PATH/lib.backup.sh

# Chargement de la config par défaut (OVH), serveur de prod
msg=$msg"\nloading $LIB_PATH/config_default.sh"
. $LIB_PATH/config_default.sh


## Chargement éventuel d'une config alternative par machine
## On peut écraser toutes les valeurs
#  Finalement ce n'est pas une si bonne idée car sur OVH le
#  hostname varie... Donc je fixe un nom à config_priv comme
#  privée
export D_ETC="$(echo $LIB_PATH | sed -e "s@\/cgi-bin\$@\/cgi-etc@" )"
if [ "$D_ETC" = "$LIB_PATH" ]; then
    # So nothing done... must look ahead
    export D_ETC="$(echo "$LIB_PATH/../cgi-etc" )"

fi   
if [ "$D_ETC" = "$LIB_PATH" ]; then
    echo "boot.sh :  D_ETC=\$D_ETC and \$LIB_PATH are the same : '$D_ETC'"
    echo "boot.sh :  D_ETC must end with 'cgi-bin'. Fatal error."
    exit 254 # 666 >256
fi
if [ ! -d "$D_ETC" ]; then
    die "boot.sh : cannot find D_ETC=\$D_ETC from \$LIB_PATH=$LIB_PATH"
fi


#  Mais pour les machines des copains on peut encore redéfinir
#  les variables tranquillou
hostname=$(hostname -s)
f_host="$D_ETC/config_${hostname}.sh"


f_priv=$D_ETC/config_priv.sh
if [ -f "$f_priv" ]; then
    msg=$msg"\nloading config_priv.sh"
    . "$f_priv"
else
    if [ ! -f "$f_host" ]; then
        echo "boot.sh : cannot find $f_priv (nor $f_host)" 2>&1
        # So no log files available
        exit 254 #666
    fi
fi

if [ -f "$f_host" ]; then
    msg=$msg"\nloading config_${hostname}.sh"
    . "$f_host"
fi

###
### Checks on common variables
###
check_local_server_variables


#
#  Localement à ce serveur, il y a deux types de scripts. Ceux qui s'occupent
#  que de sauvegarder les données sur lui même (dits scripts locaux) et ceux qui
#  servent à répliquer une machine (dits scritps distants). Ces derniers ont une
#  possibilité de configuration par le fichier ci-dessous.
#  FAb: sur mon serveur les BD sont différents donc ces 2 sortent de scripts
#  doivent pouvoir utiliser des jeux différents de données.
#  sMode = CLI (client)  ou SRV (server)
ME=$(basename $0)
case $ME in
    backup_*)
        msg=$msg"\nLocal script skip bonus"
        sModeCV='SRV'
        ;;
    *)
        sModeCV='CLI'
        msg=$msg"\nDist script... bonus !"
        cfg_dist="$D_ETC/config_${hostname}_dist.sh"
        #echo "cfg_dist=$cfg_dist"
        if [ -f "$cfg_dist" ]; then
            msg=$msg"\nloading $cfg_dist"
            . "$cfg_dist"

            ## Perform controls now
            check_client_variables

            . $LIB_PATH/lib.import.sh
        else
            msg=$msg"\nno '$cfg_dist' found"
        fi
        ;;
esac

if [ "x$1" = "x-f" ]; then
    if [ "x$2" != "x" ]; then
        if [ ! -f "$2" ]; then
            error "Cannot find additionnal config file $2"
        else
            msg=$msg"\nloading config $2"
            . "$2"
        fi
    else
        error "Missing argument for config file"
    fi
fi

debug "$msg"

 if  [ "$ME" != "fix_fs.sh" ]; then
     if [ $DEBUG -ne 0 ]; then
         viewConfig
     fi
 fi

 ### Start!

taskReportInit
logStart
