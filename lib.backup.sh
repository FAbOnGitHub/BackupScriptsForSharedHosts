# lib.backup.sh
#   ex general.sh
#  - initial author : meo
#  - main dev : FAb
#
# Fonctions générales et utilitaires en tout genre.
#
# Licence  GPL v3
#
LOG_MAX_SIZE=1000      # Nb d'entrées dans le journal
TMP_FILE=/tmp/log.tmp  # Découpe journal

### Nom interne du projet
###  Ne sert qu'au sujet du message mail
PRJ="RLBackup"

##
# Variable pour les backups MySQL, les tables dont le nom commencent
# par cette chaîne sont exclues de backup_mysql_full.sh
MYSQL_DB_EXCLUDE_PREFIX=
# Variable pour faire des dumps par lot de X lignes où X=SQL_DUMP_INTERVAL
# 10000 est sûr mais peut-être customisé dans la conf
SQL_DUMP_INTERVAL=100000

##
# Compress et crypto variables
sCompressProg=/bin/gzip
sCompressArgs='-9'
sCypherProg=/usr/bin/gpg2
sCypherArgs=

##
# moveXferZoneAutoPurge à 0permet de ne pas effacer les dumps non chiffrés
#  *déconseillé* mais utile en débug
bMoveXferZoneAutoPurge=1

##
# Mail variables
bUseMailWarning=1
bMailCommandAvaible=1
NOTIFY_SUBJECT="Errors occured, please inspect log='%LOG_FILE'"
MAIL_FROM=
## Attention %LOG_FILE = template

# $LOG_FILE n'est pas encore définie
##
# Système qui permet au serveur source (à sauvegarder) de définir des fichiers
# supplémentaire à sauver sans que l'administrateur du serveur de destination
# n'ait à intervenir.
# Si tout se passe bien cela ajoute la liste contenue dans le fichier à la
# variable $BAK_FILES
# Sans effet sur le serveur à sauvegarder
# Peut-être désactivé via dans config_dist_xxxx.sh
bUseDistantBakFile=1
sDistantBakFilename="Please_backup.lst"

DEBUG=${DEBUG:-0}

let _iNbTaskCount=0
let _iNbTaskOk=0
let _iNbTaskErr=0
let _iNbTaskWarn=0
export _iNbTaskCount _iNbTaskOk _iNbTaskErr _iNbTaskWarn



###
# Functions

# sizeOf $file
#
# Taille d'un fichier en octets
function sizeOf()
{
    wc -c $1 | awk '{print $1}'
}

#
# size_to_human
#  If numfmt is awailable do :
#    4296 -> 4.2KiB in $human_size
#  else return 4296.
# Warning always use bytes is a good idea
bNumFmt=${bNumFmt:-0}
function size_to_human()
{
    sz=$1
    if [ $bNumFmt -eq 1 ]; then        
        human_size="$(numfmt --to=iec-i --suffix=B --format="%f" $sz)"
    else
        human_size="$sz"
    fi
}


# lineOf $file
#
# Nombre de ligne d'un fichier

linesOf ()
{
  if [ -f $1 ]; then
    wc -l $1 | awk '{print $1}'
  else
    echo 0
  fi
}

# checkSum $file
#
# Retourne la somme de contrôle de $file

function checkSum()
{
  cksum $1 | awk '{print $1}'
}

function checkSumFile()
{
    checkSum "$1" > "$1".csum
}

# log $file $msg
#
# Ecrit un message dans un journal FIFO d'au plus LOG_MAX_SIZE entrées.
#  OBSOLETE
function log()
{
  echo `date +%a\ %d/%m/%g\ %X` `basename $0` ":" $2 > $TMP_FILE
  head -n $[$LOG_MAX_SIZE - 1] $1 >> $TMP_FILE 2> /dev/null
  mv -f $TMP_FILE $1
}

# fileRotate $file $nCopy
#
# Rotation file.1 -> file.2 -> file.nCopy -> drop
#   OBSOLETE
function fileRotate ()
{
    if [ "x$1" = "x" ]; then
        log $LOG_FILE "fileRotate missing arg1"
        exit 1
    fi
    if [ "x$2" = "x" ]; then
        log $LOG_FILE "fileRotate missing arg2"
        exit 1
    fi

    i=$2
    while [ $i -gt 1 ]; do
        let j=i-1
        [ -e $1.$j ] && mv -f $1.$j $1.$i
        let i=i-1
    done
}

# debug $msg
#
# Affiche un message de débogage
function debug()
{
    if [ ! -f $LOG_FILE ]; then
        echo -e "`date +"%F %T"` DBG : $@" 2>&1
        return 0
    fi
    case "x$DEBUG" in
        "x0"|"x1"|"x2")
            if [ $DEBUG -gt 0 ]; then
                [ $DEBUG -gt 1 ] && echo -e "DBG : $@"
                echo -e "`date +"%F %T"` DBG : $@" >>$LOG_FILE
            fi
            ;;
        *)
            echo "debug() error : [DEBUG=$DEBUG]"
            __fm_error
            exit 123
            ;;
    esac
}

function __fm_trace()
{
    iNbLines=$(awk 'BEGIN{ i=0}
        { i++}
        END{ printf("%d\n", log(i) / log(10) +1)}' "${BASH_SOURCE[0]}")
    [ "x$1" = "x" ] && iSkip=0 || iSkip=$1
    #error "Call stack:"
    for((i=$iSkip; i<${#BASH_LINENO[*]}; i++))
    do
        printf "%s: line %0"$iNbLines"d: call %s\n" "${BASH_SOURCE[$i]}" \
               "${BASH_LINENO[$i]}"  ${FUNCNAME[$i]} 2>&1
        
        if [ $i -gt 42 ]; then
            echo "__fm_trace(): suicide"
            exit 123
        fi
    done
    return 0
}
function __fm_error()
{
    __fm_trace 2
    return 1
}

# Use a simpel df to determine available space
# Output :
#  $disk : device
#  $size : size used in human readable
#  $ppc : percentage used
#  $iPPC : ppc without '%'
#  $mp : mount-point
function simple_disk_space()
{
    dir="$1"
    if [ "x$dir" = "x" ]; then
        fileLogger "simple_disk_space() missing argument"
        exit $EXIT_FAILURE
    fi
    export $(df -PH "$dir" 2>/dev/null \
                 | awk '/^\// {printf( "disk=%s size=%s ppc=%s mp=%s\n", $1, $4, $5, $6) }' \
                       2>/dev/null)
    let iPPC=${ppc//%/}
    export iPPC
}  

function report_disk_space()
{
    if [ $REPORT_DISK_USAGE -ne 1 ]; then
        return
    fi
    
    dir="$1"
    max="$2"
    comment="$3"
    if [ "x$1" = "x" ]; then
        dir="$PWD"
    fi
    if [ "x$max" != "x" ]; then
        let iMax=${max//%/}  # Remove %
    elif [ "x$DISK_USAGE_WARNING" != "x" ]; then
        let iMax=$DISK_USAGE_WARNING
    else
        let iMax=80
    fi

    taskRegister
    buffer1="$(df -PH $dir 2>/dev/null |grep '^/')"
    buffer2="$(df -PH $dir 2>/dev/null |grep '^-')"
    buffer3="$(df -P $(stat -c '%m' $dir 2>/dev/null) 2>/dev/null)"
    if [ "x$buffer1" != "x" ]; then  
        export $(df -PH $dir 2>/dev/null \
                     | awk '/^\// {printf( "disk=%s size=%s ppc=%s mp=%s\n", $1, $4, $5, $6) }' \
                           2>/dev/null)
    elif [ "x$buffer2" != "x" ]; then
        # df: Warning: cannot read table of mounted file systems: No such file or directory
        # Filesystem      Size  Used Avail Use% Mounted on
        # -                18T  4,9T   13T  29% /home/user123
        export $(df -PH $dir 2>/dev/null \
                     | awk '/^-/ {printf( "disk=%s size=%s ppc=%s mp=%s\n", $1, $4, $5, $6) }' \
                           2>/dev/null)
    elif [ "x$buffer3" != "x" ]; then
        taskWarn
        fileLogger "$WARN $L_CHECKDISK 'df' error. Please consider usage of stat -c %m"
        return $EXIT_FAILURE
    else
        if [ $BUG_CMD_DF = $BUG_IGNORE ]; then
            taskCancelled
            fileLogger "$INFO $L_CHECKDISK 'df' bug accepted"
            return $EXIT_SUCCESS
        elif [ $BUG_CMD_DF = $BUG_WARN ]; then
            taskWarn
            fileLogger "$WARN $L_CHECKDISK 'df' error -- dir='$dir'"
        else
            taskErr
            fileLogger "$KO $L_CHECKDISK 'df' error -- dir='$dir'"
        fi
        return $EXIT_FAILURE
    fi
    
    sMsg=" available space on $disk is $size ($ppc, limit is $iMax) $comment"
    let iPPC=${ppc//%/}
    if [ $iPPC -eq 100 ]; then
        taskErr
        fileLogger "$KO $L_CHECKDISK Disk full!! : $sMsg"
    elif [ $iPPC -ge $iMax ]; then
        taskWarn
        fileLogger "$warn $L_CHECKDISK= limit reached : $sMsg"
    else
        taskOk
        fileLogger "$ok $L_CHECKDISK $sMsg"
    fi
}


# Formate le message de debut et le pousse dans le fichier
function fileLogger()
{
    if [ $bUseLogger -eq 1 ]; then
        logger "b4sh $(basename $0) : $@"
    fi

    LOG_FILE=${LOG_FILE:-'/tmp/backup_scripts.log'}
    if [ ! -f $LOG_FILE ]; then
        __fm_error
    fi
    echo "$(date +"%F %T") b4sh $(basename $0) : $@" >> $LOG_FILE
}

function logStart()
{
    sMsg="<<<<<<< $ME starting"
    fileLogger "$sMsg"
    DATE=$(date +"%Y%m%d-%H%M%S")
    echo "$sMsg $DATE" >> $ERR_FILE
}
function logStop()
{
    sMsg=">>>>>>> $ME stopping : $@"
    fileLogger "$sMsg"
    DATE=$(date +"%Y%m%d-%H%M%S")
    echo "$sMsg $DATE" >> $ERR_FILE
}

##
## Functions and variables to count good task and erors...
function taskReportInit()
{
    _taskReportCounters="(ok:/w:/e:)"
    _taskReportLabel="[--] $_taskReportCounters"
    let _iNbTaskCount=0
    let _iNbTaskOk=0
    let _iNbTaskErr=0
    let _iNbTaskWarn=0
}
function taskCount()
{
    let _iNbTaskCount++
}
function taskRegister()
{
    let _iNbTaskCount++
}
function taskCancelled()
{
    let _iNbTaskCount--
}
function taskOk()
{
    let _iNbTaskOk++
}
function taskErr()
{
    let _iNbTaskErr++
}
function taskStatus()
{
    rc="$1"
    if [ $rc -eq $EXIT_SUCCESS ]; then
        taskOk
    else
        taskErr
    fi
}
# Permits to do taskStatus withour declaring taskCount
function taskAddAndStatus()
{
    taskCount
    taskStatus "$1"
}

function taskWarn()
{
    let _iNbTaskWarn++
}
function taskReportStatus()
{
    local status

    if [ $sModeCV = "SRV" ]; then
        report_disk_space $BAK_DIR $DISK_USAGE_WARNING "BAK_DIR=$BAK_DIR"
    else
        report_disk_space $BAK_DIR_CLI $DISK_USAGE_WARNING "BAK_DIR_CLI=$BAK_DIR_CLI"
    fi
    
    taskReportCounters
    let _iNbTaskTotal=$_iNbTaskOk+$_iNbTaskErr+$_iNbTaskWarn
    if [ $_iNbTaskTotal -ne $_iNbTaskCount ]; then
        status="[!!]"
    elif [ $_iNbTaskErr -eq 0 ]; then
        status="[ok]"
    else
        status="[KO]"
    fi
    _taskReportLabel="$status $_taskReportCounters"
}
function taskReportCounters()
{
    _taskReportCounters="(ok:${_iNbTaskOk}/w:${_iNbTaskWarn}/e:${_iNbTaskErr}/T:${_iNbTaskCount})"
}

# Can lie on exit status.
# See variable BUG_HONOR_EXIT
function mainExit()
{
    rc=$1
    if [ $BUG_HONOR_EXIT -eq $TRUE ]; then
        exit $rc
    fi
    exit $EXIT_SUCCESS
}

###
# Afficher les logs du jour, pour envoi par email par exemple.
#
function view_today_logs()
{
    grep "^$(date +"%F")" $LOG_FILE
}

bMailInit=0
function init_mail()
{
    [ $bMailInit -eq 1 ] && return $EXIT_SUCCESS

    # Is mail command avaible ?
    bMailCommandAvaible=0
    which mail >/dev/null 2>&1
    rc=$?
    if [ $rc -eq 0 ]; then
        bMailCommandAvaible=1
    fi
    bMailInit=1
}

###
# Envoi de messages par email
# $1 : sujet optionnel
function _notify_email()
{
    if [ $bUseMailWarning -ne 1 ]; then
        fileLogger "notify_email() called but \$bUseMailWarning  is not set."
        return $EXIT_FAILURE
    fi

    init_mail

    if [ "x$NOTIFY_TO" = "x" ]; then
        error " NOTIFY_TO is not set"
        fileLogger "notify_email() NOTIFY_TO is empty."
        return $EXIT_FAILURE
    fi
    if [ "x$1" = "x" ]; then
        SUBJECT="$(echo "[$PRJ] $NOTIFY_SUBJECT (--by $ME)"| sed -e "s@%LOG_FILE@"${LOG_FILE}"@g")"
    else
        SUBJECT="[$PRJ]$1 (by $ME)"
    fi

    if [ "x$MAIL_FROM" != "x" ]; then
	mail_from_arg="-r $MAIL_FROM"
    elif [ "x$NOTIFY_FROM" != "x" ]; then
	mail_from_arg="-r $NOTIFY_FROM"
    else
	mail_from_arg=""
    fi

    
    if [ $bMailCommandAvaible -eq 1 ]; then
        mail -s "$SUBJECT" $mail_from_arg $NOTIFY_TO
        rc=$?
    else
        echo "$KO *** mail not found : $NOTIFY_TO" >> $LOG_FILE
        cat - >> $LOG_FILE
        rc=13
    fi
    if [ $rc -eq $EXIT_SUCCESS ]; then
        status=$ok
    else
        status=$KO
    fi
    # I know !! It's after the mail. Too late but I don't want to lose any
    # information
    fileLogger "$status $L_MAIL to:'$NOTIFY_TO'"
}
##
# Envoi un message mais en laissant la lecture de stdin à faire.
function notify_email_stdin()
{
    _notify_email "$@"
}
##
# Envoi un message par mail
# $1 : le suject (optionnel)
function notify_email()
{
    echo "Message sent from $ME"| _notify_email "$@"
}

function reportByMail ()
{
    if [ $bUseMailWarning -eq 1 ]; then
        if [ "x$1" = "x" ]; then
            sReport="$ME autoreport"
        else
            sReport="$1"
        fi
        if [ "x$2" != "x" ]; then
            view_today_logs | grep "$2" | notify_email_stdin "$sReport"
        else
            view_today_logs| notify_email_stdin "$sReport"
        fi
    fi
}

##
# juste pour activer une erreur qui sera réutilisée en fin de programe
function hasFailed()
{
    GENERAL_SUCCESS=$EXIT_FAILURE
}


###
### Stdin/Stdout
###
#
#  Écrit sur stderr (utilisé par la fonction help, conforme à POSIX)
#
function error()
{
    if [ "x$LOG_FILE" = "x" ]; then
        echo -e "$*" 1>&2
    fi
    fileLogger "$ERRO $*"
}

#
#  Comme perl & php
#
function die()
{
    error "$*"
    exit $EXIT_FAILURE
}

SAY_MODE_OLD=
function say_mode_quiet()
{
    SAY_MODE_OLD=$SAY_MODE
    SAY_MODE='QUIET'
}
say_mode_restore()
{
    SAY_MODE=$SAY_MODE_OLD
}


#
# Fonctions sur les dates
#
date2stamp () {
    date --utc --date "$1" +%s
}

stamp2date (){
    date --utc --date "1970-01-01 $1 sec" "+%Y-%m-%d %T"
}
# Use dateDelta as result
dateDiff ()
{
    dateDelta=0
    case $1 in
        -s)   sec=1;      shift;;
        -m)   sec=60;     shift;;
        -h)   sec=3600;   shift;;
        -d)   sec=86400;  shift;;
        *)    sec=86400;;
    esac
    dte1=$(date2stamp $1)
    dte2=$(date2stamp $2)
    diffSec=$((dte2-dte1))
    if ((diffSec < 0)); then abs=-1; else abs=1; fi
    dateDelta=$((diffSec/sec*abs))
    return 0
}

# Common function to avoid the bug of %w instead of %u
function dayOfWeek()
{
    LC_ALL=C date +"%u-%a"
}



####
#### Fonctions agissant sur des fichiers et qui pourraient être utiles en scripts
####


f_current=  # Nom du fichier manipulé. Permet de chaîner des foncions en y
            # plaçant la valeur du fichier produit

function build_archive_prefix()
{
    h=$(hostname -s)
    new="$h"
    if [ "x$TASK_NAME" != "x" ]; then
	new="${h}.${TASK_NAME}"
    fi
    ARCHIVE_PREFIX="$new"
}


# Compresse un fichier avec le paramètre kivabien
function do_compress()
{
    arch="$1.zip"
    src="$1"
    if [ "x$2" != "x" ]; then
        arch="$1"
        src="$2"
    fi
    if [ $bDoCompress -eq 0 ]; then
        f_current="$src"
        return 0
    fi
    rm -rf "$arch"
    zip -qr9 -P $ZIP_PASSWD "$arch" "$src"  2>&1 | tee -a $ERR_FILE
    rc=$?
    if [ $rc -ne 0 ]; then
        fileLogger "$KO cmd zip failed rc=$rc"
    fi

    rm -rf "$src"
    f_current="$arch"
    return $rc
}
function do_compress_clean()
{
    arch=""
    src="$1"
    if [ "x$2" != "x" ]; then
        arch="$1"
        src="$2"
    fi
    do_compress "$arch" "$src"
    rc=$?
    if [ $rc -eq $EXIT_SUCCESS ]; then
        rm -rf "$src"
        fileLogger "$ok $L_COMPRESS $ME"
    else
        fileLogger "$KO $L_COMPRESS $ME '$src' failed, not cleaned"
    fi
    return $rc
}

#
# Cherche la méthode de chiffrement à utiliser :
#  Si on peut utiliser GPG ?
#   - SiGPG avec clé asyétrique ?
#     -- cool
#     -- sinon GPG avec passphrase
#   - sinon zip.
#
# Exemple de chiffrement symétrique :
# gpg --no-use-agent -q  -c  --passphrase $GPG_PASSWD $file

bCypherInit=0
function init_cypher()
{
    [ $bCypherInit -eq 1 ] && return $EXIT_SUCCESS

    # Zip in default. ZIP_PASSWD always set.
    sCypherFct="do_cypher_zip"

    which $sCypherProg >/dev/null
    rc=$?
    if [ $rc -eq 0 ]; then
        if [ "x$GPG_KEYFILE" != "x" ]; then
            if [ -f "$GPG_KEYFILE" ]; then
                echo "GPG with public key not ready";
                fileLogger "gpg happy, gpg keyfile found !"
                fileLogger "$WARN gpg never tested !"
                sCypherFct="do_cypher_gpg_a"
                bCypherInit=1
                return $EXIT_SUCCESS
            else
                fileLogger "$WARN $sCypherProg cannot access to key:$GPG_KEYFILE ! Continue"
            fi
        elif [ "x$GPG_PASSWD" != "x" ]; then
            sCypherFct="do_cypher_gpg_s"
	    if [ $sCypherProg = "/bin/gpg" ]; then
		sCypherArgs=" $sCypherArgs --no-use-agent"
            else
                sCypherArgs=" $sCypherArgs --batch"
	    fi
            bCypherInit=1
            return $EXIT_SUCCESS
        else
            fileLogger "$WARN $sCypherProg has neither passphrase nor keyfile ! Continue"
        fi
    else
        ### Zip fallback
        which zip  >/dev/null 2>&1
        rc=$?
        if [ $rc -ne 0 ]; then
            error "CYPHER PANIC !! CYPHER PANIC !! (no zip program)"
            bCypherInit=0
            sCypherFct=echo
            sCypherArgs=
            return $EXIT_FAILURE
        fi
	fileLogger "$WARN $sCypherProg not found ! using zip to cypher : WEAK !"
    fi

    bCypherInit=1
    return $EXIT_SUCCESS
}

function do_cypher()
{
    f="$1"
    init_cypher
    if [ "x$sCypherFct" = "x" ]; then
        error "$ME misconfiguration sCypherFct"
        return $EXIT_FAILURE
    fi
    $sCypherFct "$f"
    rc=$?
    if [ $rc -eq $EXIT_SUCCESS ]; then
        #rm -f "$f"
        fileLogger "$ok $L_CYPHER $ME"
    else
        fileLogger "$KO $L_CYPHER $ME '$f' failed"
    fi
    return $rc
}

function do_cypher_zip()
{
    f="$1"
    zip  -qr9 -P "$ZIP_PASSWD" "$f".zip "$f" 2>&1 | tee -a $ERR_FILE
    rc=$?
    [ $rc -eq 0 ] && echo "$f".zip || echo ""
    return $rc

}
function do_cypher_gpg_a()
{
    echo "$ME: WARNING ! No tested!"
    f="$1"
    #$sCypherProg $sCypherArgs $GPG_KEYFILE --yes "$f" 2>&1 | tee -a $ERR_FILE
    $sCypherProg $sCypherArgs $GPG_KEYFILE --yes "$f" 2> >(tee -a $ERR_FILE >&2)
    rc=$?
    [ $rc -eq 0 ] && echo "$f".gpg || echo ""
    return $rc

#    mv "$f".gpg "$f".X
}
function do_cypher_gpg_s()
{
    f="$1"

#    $sCypherProg $sCypherArgs -q -c --passphrase "$GPG_PASSWD" \
#                 --yes "$f"  2>&1 | tee -a $ERR_FILE
    $sCypherProg $sCypherArgs -q -c --passphrase "$GPG_PASSWD" \
                 --yes "$f"  2> >(tee -a $ERR_FILE >&2)
    rc=$?
    [ $rc -eq 0 ] && echo "$f".gpg || echo ""

    return $rc
    #mv "$f".gpg "$f".X
}

MYSQL_SESAME=
function mysql_prepare_connexion()
{
    [ "x$1" = "x" ] && die "$KO \$MYSQL_HOST is empty"
    [ "x$2" = "x" ] && die "$KO \$MYSQL_USER is empty"
    [ "x$3" = "x" ] && die "$KO \$MYSQL_PASS is empty"
    _port="$4"
    [ "x$4" = "x" ] && _port=3306

    f=$(mktemp $BAK_DIR/sesame.XXXXXXXX.cnf)
    chmod 600 "$f"
    echo "
[client]
host=$1
user=$2
password=$3
port=$_port
" > $f    
    export $(mysql --defaults-file="$f" --help|\
                 awk '/^max-allowed-packet/ {print "max_allowed_packet=" $2} ')
    echo "max_allowed_packet=$max_allowed_packet" >> "$f"
    echo "net_buffer_length=$max_allowed_packet" >> "$f"

    MYSQL_SESAME="$f"
    debug "> MYSQL_SESAME=$f"
}
function mysql_clean_up()
{
    rm -f "$MYSQL_SESAME"
}

#
#  do_moveXferZone: cette fonction prend un fichier et va le déposer dans
#   la zone d'échange "publique" BAK_DIR en
#   - vérifiant que cette zone soit protégée
#   - en chiffrant le fichier
#   - générant une empreinte cksum du chiffré
#   Il y a deux écoles :
#   - au mieux, on dépose même si ce n'est pas sécurisé pour toujours pouvoir
#     extraire les sauvegardes
#   - méthode zélée : au moindre doute cela ne fait rien, on n'expose rien.
#
function do_moveXferZone()
{
    f="$1"
    if [ "x$f" = "x" ]; then
        fileLogger "do_moveXferZone() : no argument"
        return $EXIT_FAILURE
    fi
    if [ ! -f "$BAK_DIR_PUB/.htaccess" ]; then
        fileLogger "$KO $L_OFFER BAK_DIR_PUB <> .htaccess ! Abort."
        return $EXIT_FAILURE
    fi
     
    sSize="$(du --si -s $f| awk '{print $1}' )"
    do_compress "$f"
    rc=$?
    debug "do_compress rc=$rc"
    if [ $rc -eq $EXIT_SUCCESS ]; then
        f="$f_current"
    fi

    X="$(do_cypher "$f")"
    rc=$?
    debug "do_cypher rc=$rc"
    if [ $rc -ne 0 ]; then
        error "ERROR cypher f='$f' (rc=$rc)"
        rm -rf "$f"
        return $EXIT_FAILURE
    fi
    if [ $bMoveXferZoneAutoPurge -ne 0 ]; then
        rm -rf "$f"
    fi
    F="$(basename "$X")"
    debug " [f=$f][X=$X][F=$F] $do_cypher_fct"
    debug " [BAK_DIR=$BAK_DIR][BAK_DIR_PUB=$BAK_DIR_PUB]"

    buffer=" $sSize->$(du --si -s "$X")"
    if [ "x$BAK_DIR" != "x$BAK_DIR_PUB" ]; then
        mv -f "$X" "$BAK_DIR_PUB/$F" 2>/dev/null
    fi
#    checkSumFile "$BAK_DIR_PUB/$F"
    writeMetaData "$BAK_DIR_PUB/$F"
    readMetaDataOldWay "$BAK_DIR_PUB/$F".meta
    fileLogger "$ok $L_OFFER $buffer csum:$csumFile at $dateFile"
    return $EXIT_SUCCESS
}

# Bug fix : use UTC date on both side
# $ date -u "+%F-%T"; date  "+%F-%T"; 


#
# Write the metadata of a file.
# Used by do_moveXferZone
#
function writeMetaData()
{
    file="$1"
    if [ ! -f "$file" ]; then
        error "writeMetaData() file '$file' not found"
        return $EXIT_FAILURE
    fi
    metafile="$file".meta

    # simple chekcum
    cksum "$file" | awk '{print $1}' > "$metafile"
    # Size
    du -b "$file" | awk '{print $1}' >> "$metafile"
    # time of last status change, seconds since Epoch
    stat -c "%Z" "$file" >> "$metafile"
    # Human reable version (not used)
    stat -c "%z" "$file" >> "$metafile"
    return $EXIT_SUCCESS
}

#
# Read the metadata file and populate variables
#
function readMetaData()
{
    metafile="$1"
    csumFile=
    sizeFile=
    epochFile=

    if [ ! -f "$metafile" ]; then
        error "readMetaData() file '$metafile' not found"
        return $EXIT_FAILURE
    fi
    mapfile -t META < "$metafile"
    csumFile=${META[0]}
    sizeFile=${META[1]}
    epochFile=${META[2]}
    unset META[0]; unset META[1]; unset META[2]
    dateFile="${META[*]}"

    if [ $DEBUG -eq 1 ]; then
        echo "Meta: " ${META[*]}
        echo "csum: " $csumFile
        echo "size: " $sizeFile
        echo "date: " $epochFile
        unset META[0]; unset META[1]; unset META[2]
        echo "DATE: " $dateFile
    fi
    return $EXIT_SUCCESS
}

##
## Arg... with bash-3.2.25 mapfile is not available
function readMetaDataOldWay()
{
    metafile="$1"
    csumFile=
    sizeFile=
    epochFile=

    if [ ! -f "$metafile" ]; then
        error "readMetaData() file '$metafile' not found"
        return $EXIT_FAILURE
    fi

    OLDIFS="$IFS"
    IFS=$'\n'
    META=( $(cat $metafile) ) # array
    IFS=$OLDIFS

    csumFile=${META[0]}
    sizeFile=${META[1]}
    epochFile=${META[2]}
    unset META[0]; unset META[1]; unset META[2]
    dateFile="${META[*]}"

    if [ $DEBUG -eq 1 ]; then
        echo "Metal = " ${META[*]}
        echo "csum: " $csumFile
        echo "size: " $sizeFile
        echo "date: " $epochFile
        echo "DATE: " $dateFile
    fi
    return $EXIT_SUCCESS
}



####
#### Fonctions de vérifications du système de fichier
####
function check_cmd()
{
    if [ ! -f "$1" ]; then
        if [ "x$2" = "xoption" ]; then
            say " $NOTFOUND optional command $1 not found."
            return $EXIT_SUCCESS
        else
            say " $NOTFOUND command    $1 not found."
            return $EXIT_FAILURE
        fi
    fi
    if [ ! -x "$1" ]; then
        say " $NOTEXEC command $1 not executable."
        return $EXIT_FAILURE
    fi
    say " $ok command   '$1'."
    return $EXIT_SUCCESS
}

function check_dir()
{
    d="$1"
    shift
    if [ -d "$d" ]; then
        status="$ok"
        rc=$EXIT_SUCCESS
    else
        status="$KO"
        say " $status directory '$d' not found"
        return $EXIT_FAILURE
    fi
    [ -r "$d" ] && r="r" || r="-"
    [ -w "$d" ] && w="w" || w="-"
    OLDPWD=$PWD
    cd "$d" 2>/dev/null
    [ $? -eq 0 ] && x="x" || x="-"
    cd $OLDPWD
    say " $status directory '$d' ($r$w$x) $@"
    return $rc
}
function check_dir_private()
{
    dir="$1"
    say "$t3 protection for '$dir'"
    check_dir $@
    rc=$?
    [ $rc -ne $EXIT_SUCCESS ] && return $rc
    check_file "$dir/.htaccess"
    rc=$?
    [ $rc -ne $EXIT_SUCCESS ] && return $rc
    check_passfile "$dir/.htaccess"
    rc=$?
    [ $rc -ne $EXIT_SUCCESS ] && return $rc
    check_file "$dir/index.html" "Permettrait d'éviter le listage" "option"
    rc=$?
    return $rc
}
function check_file()
{
    xo="no"
    f="$1"
    if [ "x$2" != "x" ]; then
        cmt="$2"
        [ "x$3" != "x" ] && xo="$3" || xo="-"
    fi

    if [ -h "$f" ]; then
        F="$(readlink -e $f)"
        say " [_link_] file      '$f'->'$F'"
        f="$F"
    fi

    rc=$EXIT_FAILURE
    if [ -f "$f" ]; then
        rc=$EXIT_SUCCESS
        status="$ok"
    else
        if [ "$xo" = "option" ]; then
            status="$WARN"
            rc=$EXIT_SUCCESS
        else
            status="$KO"
            rc=$EXIT_FAILURE
        fi
    fi
    [ -r "$f" ] && r="r" || r="-"
    [ -w "$f" ] && w="w" || w="-"
    [ -x "$f" ] && x="x" || x="-"
    say " $status file      '$f' ($r$w$x) $cmt (rc=$rc)"
    return $rc
}
function check_writable()
{
    o="$1"
    shift
    if [ -w "$o" ]; then
        status="$ok"
        rc=$EXIT_SUCCESS
    else
        status="$KO"
        rc=$EXIT_FAILURE
    fi
    say " $status object    '$o' is writable ? $@"
    return $rc
}

#
# vérifie un fichier .htaccess
#
function check_passfile()
{
    f="$1"
    say_mode_quiet
    check_file "$f"
    rc=$?
    say_mode_restore
    [ $rc -ne $EXIT_SUCCESS ] && return $rc

    sAllow=$(grep -i "allow from " "$f" 2>/dev/null)
    if [ "x$sAllow" = "x" ]; then
        say " $WARN           .htaccess: no clause allow from"
    else
        say " $info           allow from : $sAllow"
    fi

    pass_file=$(grep AuthUserFile "$1" |awk '{ print $2 }')
    check_file "$pass_file"  "$strMsgKOACorriger  (passfile)"
    rc=$?
    return $rc
}

function fix_execbit()
{
    f="$1"
    shift
    rc=$EXIT_SUCCESS
    if [ ! -f "$f" ]; then
        say " $NOTFOUND execbit   '$f'"
        return $EXIT_FAILURE
    fi
    if [ ! -x "$f" ]; then
        chmod a+x "$f"
        if [ -x "$f" ]; then
            status="[fixed!]"
        else
            status="$KO"
            rc=$EXIT_FAILURE
        fi
    else
        status="$ok"
    fi
    say " $status umask     '$f' : droit d'exécution. $@"
    return $rc
}

function say()
{
    if [ "x$SAY_MODE" != "xQUIET" ]; then
        echo "$@"
    fi
    [ -w $LOG_FILE ] && echo "$@" >> $LOG_FILE
}

###
### Variables et chemin
###
function check_var()
{
    for f in $*
    do
        var=$f
       # local val=$( echo $(echo $"$var") )
        eval val=\$"$var"
        [ "x$val" = "x" ] && label="(unset)" || label="( set ) $val"
        out=$(printf "%s %19s=%s" "$info" "$var" "$label")
        #say " $info $var=$label"
        say "$out"
    done
}
function check_var_secret()
{
    for f in $*
    do
        var=$f
       # local val=$( echo $(echo $"$var") )
        eval val=\$"$var"
        if [ "x$val" = "x" ]; then
            label="(unset)"
        else
            val="$(echo "$val"|sed -e "s/./*/g")"
            label="( set ) $val"
        fi
        out=$(printf "%s %19s=%s" "$info" "$var" "$label")
#        say " $info $var=$label"
        say "$out"
    done
}
#
# Affiche une URL en enlevant le mdp
function check_var_URL()
{
    for f in $*
    do
        https=
        var=$f
       # local val=$( echo $(echo $"$var") )
        eval val=\$"$var"
        if [ "x$val" = "x" ]; then
            label="(unset)"
        else
            https="$(echo $val | grep -i '^https://')"
            val="$(echo "$val"|sed -e "s~://.*@~://(user:secret)@~g")"
            label="( set ) $val"
        fi
        out=$(printf "%s %19s=%s" "$info" "$var" "$label")
#        say " $info $var=$label"
        say "$out"
        [ "x$https" = "x" ] && say " $WARN Le mode SSL de HTTP devrait être activé."
    done
}

function check_local_server_variables()
{
    # We need logfile immediatly
    # but they can be declared in BAK_DIR with could not exists yet
    if [ "x$LOG_FILE" = "x" ]; then
        export LOG_FILE=/tmp/scripts_b4sh_${USER}.txt
        touch $LOG_FILE
        chmod o-rwx $LOG_FILE
        echo "ALERT: LOG_FILE not set, using default $LOG_FILE"
    fi
    if [ "x$ERR_FILE" = "x" ]; then
        export ERR_FILE=$LOG_FILE
        echo "Set error file to log file $(date)" >> $ERR_FILE
        chmod o-rwx $ERR_FILE
    fi

    if [ $bUseLogger -eq 1 ]; then
        which logger >/dev/null 2>&1
        rc=$?
        if [ $rc -ne 0 ]; then
            fileLogger "sorry, can't use logger"
            bUseLogger=0
        fi
    fi

    # Can we use numfmt ?
    bNumFmt=0
    which numfmt >/dev/null 2>&1
    rc=$?
    if [ $rc -eq 0 ]; then
        bNumFmt=1
    fi

    if [ "x$BAK_DIR" = "x" ]; then
        fileLogger "BAK_DIR not defined: how can it be possible?"
        exit 123
    fi
    if [ ! \( -d $BAK_DIR -a -w $BAK_DIR \) ]; then
        fileLogger "$KO ERR $BAK_DIR not dir or writeable"
        exit 1
    fi

    if [ "x$BAK_DIR_PUB" = "x" ]; then
        fileLogger "BAK_DIR_PUB not defined: set to BAK_DIR=$BAK_DIR"
        #echo "BAK_DIR_PUB not defined: set to BAK_DIR=$BAK_DIR"
        BAK_DIR_PUB=$BAK_DIR
    fi

    if [ "x$BAK_DIR_PUB" = "x$BAK_DIR" ]; then
        fileLogger "$WARN BAK_DIR_PUB and BAK__DIR are the same, this a bad idea"
    fi
    case "$BAK_DIR_PUB" in
        ${BAK_DIR}*)
            fileLogger "$WARN BAK_DIR_PUB is sub directory of BAK_DIR. Bad idea"
            ;;
        *)
            nope="We're cool"
            ;;
    esac



    mkdir -p $BAK_DIR $BAK_DIR_PUB
    chmod 700 $BAK_DIR
    chmod a+rx $BAK_DIR_PUB 2>/dev/null

    if [ ! -f "$LOG_FILE" ]; then
        echo "new log file ($date)" > $LOG_FILE
        chmod o-rwx $LOG_FILE
    fi

    if [ ! -f "$ERR_FILE" ]; then
        echo "no such ERR_FILE=$ERR_FILE $(date) " > $ERR_FILE
        chmod o-rwx $ERR_FILE
    fi
    case "$LOG_FILE" in
        ${BAK_DIR_PUB}*)
            nope="We're cool"
            ;;
        *)
            fileLogger "$WARN LOG_FILE should be under BAK_DIR_PUB"
            ;;
    esac
    case "$ERR_FILE" in
        ${BAK_DIR_PUB}*)
            nope="We're cool"
            ;;
        *)
            fileLogger "$WARN ERR_FILE should be under BAK_DIR_PUB"
            ;;
    esac


    if [ "x$ZIP_PASSWD" = "x" ]; then
        fileLogger "ZIP_PASSWD is not defined... default value"
        ZIP_PASSWD="NeverForgetToSetAPassowrd"
    fi

}


function check_client_variables()
{
    ZIP_PASSWD=${ZIP_PASSWD:-"NoPassUsedButControlledAnyway"}

    if [ ! -d $BAK_DIR_CLI ]; then
        fileLogger  "$KO BAK_DIR_CLI ('$BAK_DIR_CLI') is not a directory"
        exit 1
    fi
    if [ ! -w $BAK_DIR_CLI ]; then
        fileLogger  "$KO BAK_DIR_CLI ('$BAK_DIR_CLI') is not writable"
        exit 1
    fi
    if [ ! -f $BAK_DIR_PUB/.htaccess ]; then
        fileLogger "$KO you must have an .htaccess in $BAK_DIR_PUB"
        exit 1
    fi
    if [ ! -d $LTS_DIR ]; then
        fileLogger  "$WARN LTS_DIR ('$LTS_DIR') is not a directory"
        mkdir -p $LTS_DIR
        chmod a+rx $LTS_DIR
    fi
    if [ ! -w $LTS_DIR ]; then
        fileLogger  "$KO LTS_DIR ('$LTS_DIR') is not writable"
        exit 1
    fi



    if [ ! -f "$LOG_FILE" ]; then
        echo "new log file ($date)" > $LOG_FILE
        chmod a-rw $LOG_FILE
    fi

    if [ ! -f "$ERR_FILE" ]; then
        echo "no such ERR_FILE=$ERR_FILE $(date) " > $ERR_FILE
        chmod a-rw $ERR_FILE
    fi

}

function viewConfig()
{
    say " viewConfig"
    check_dir $BAK_DIR "BAK_DIR"
    check_dir $BAK_DIR_PUB "BAK_DIR_PUB"
    check_dir $BAK_DIR_PUB "BAK_DIR_PUB"
    check_file $LOCK_FILE  "[LOCK_FILE=$LOCK_FILE]"
    check_dir $LTS_DIR "LTS_DIR"
    check_file $LOG_FILE "LOG_FILE"
    check_file $ERR_FILE "ERR_FILE"
#    echo "[=]"
    echo 
    echo "[DEBUG=$DEBUG]"
    echo "[NOTIFY_TO=$NOTIFY_TO]"
    echo "[NOTIFY_FROM=$NOTIFY_FROM]"
    echo "[MAIL_FROM=$MAIL_FROM]"


}


###
# wget_error
function wget_translate_error()
{
    aErrors=( "No problems occurred." \
        "Generic error code." \
        "Parse error—for instance, when parsing command-line options, the ‘.wgetrc’ or ‘.netrc’..." \
        "File I/O error." \
        "Network failure." \
        "SSL verification failure." \
        "Username/password authentication failure." \
        "Protocol errors." \
        "Server issued an error response." \
        )
    [ "x$1" = "x" ] && die "wget_translate_error() with no args"
    if [ $1 -lt ${#aErrors[*]} ]; then
        echo ${aErrors[$1]}
    fi
}
