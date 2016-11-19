# general.sh
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

##
# Compress et crypto variables
sCompressProg=/bin/gzip
sCompressArgs='-9'
sCypherProg=/usr/bin/gpg2
sCypherArgs=
##
# Mail variables
bUseMailWarning=1
bMailCommandAvaible=1
NOTIFY_SUBJECT="Errors occured, please inspect log='%LOG_FILE'"
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

###
# Functions

# sizeOf $file
#
# Taille d'un fichier en octets
function sizeOf()
{
    wc -c $1 | awk '{print $1}'
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
    error "Call stack:"
    for((i=$iSkip; i<${#BASH_LINENO[*]}; i++))
    do
        printf "%s: line %0"$iNbLines"d: call %s\n" "${BASH_SOURCE[$i]}" \
            "${BASH_LINENO[$i]}"  ${FUNCNAME[$i]} 1>&2

    done
    return 0
}
function __fm_error()
{
    __fm_trace 2
    return 1
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
    fileLogger "<<<<<<< $ME starting"    
}
function logStop()
{
    fileLogger ">>>>>>> $ME stopping"    
}


###
# Afficher les logs du jour, pour envoi par email par exemple.
#
function view_today_logs()
{
    grep "$(date +"%F")" $LOG_FILE
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


    if [ $bMailCommandAvaible -eq 1 ]; then
        mail -s "$SUBJECT" $NOTIFY_TO
    else
        echo "$KO *** mail not found : $NOTIFY_TO" >> $LOG_FILE
        cat - >> $LOG_FILE
    fi

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




####
#### Fonctions agissant sur des fichiers et qui pourraient être utiles en scripts
####


f_current=  # Nom du fichier manipulé. Permet de chaîner des foncions en y
            # plaçant la valeur du fichier produit


# Compresse un fichier avec le paramètre kivabien
function do_compress()
{
    # if [ "x$sCompressProg" = "x" ]; then
    #     error "$ME misconfiguration sCompressProg"
    #     return $EXIT_FAILURE
    # fi
    arch="$1.zip"
    src="$1"
    if [ "x$2" != "x" ]; then
        arch="$1"
        src="$2"
    fi
    rm -f "$arch"
    zip -qr9 -P $ZIP_PASSWD "$arch" "$src" >/dev/null
    rc=$?
    f_current="$arch"
    # if [ $rc -eq $EXIT_SUCCESS ]; then
    #     checkSumFile "$new"
    #     f_current="$new"
    # fi
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
    fi

    fileLogger "$WARN $sCypherProg not found ! using zip to cypher : WEAK !"
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
        # rm -f "$f"
        fileLogger "$ok $L_CYPHER $ME"
    else
        fileLogger "$KO $L_CYPHER $ME '$f' failed"
    fi
    return $rc
}

function do_cypher_zip()
{
    f="$1"
    zip  -qr9 -P "$ZIP_PASSWD" "$f".zip "$f"
    rc=$?
    [ $rc -eq 0 ] && echo "$f".zip || echo ""
    return $rc

}
function do_cypher_gpg_a()
{
    echo "$ME: WARNING ! No tested!"
    f="$1"
    $sCypherProg  $sCypherArgs  $GPG_KEYFILE --yes  "$f"
    rc=$?
    [ $rc -eq 0 ] && echo "$f".gpg || echo ""
    return $rc

#    mv "$f".gpg "$f".X
}
function do_cypher_gpg_s()
{
    f="$1"

    $sCypherProg $sCypherArgs -q -c --passphrase "$GPG_PASSWD" --yes "$f"
    rc=$?
    [ $rc -eq 0 ] && echo "$f".gpg || echo ""

    return $rc
    #mv "$f".gpg "$f".X
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

    do_compress "$f"
    rc=$?
    if [ $rc -eq $EXIT_SUCCESS ]; then
        f="$f_current"
    fi
    
    X="$(do_cypher "$f")"
    rc=$?
    [ $rc -ne 0 ] && die "ERROR cypher f='f' (rc=$rc)"
    rm "$f"
    F="$(basename "$X")"
    debug "[f=$f][X=$X][F=$F] $do_cypher_fct"
    debug "[BAK_DIR=$BAK_DIR][BAK_DIR_PUB=$BAK_DIR_PUB]"

    buffer=$(du --si -s "$X")
    if [ "x$BAK_DIR" != "x$BAK_DIR_PUB" ]; then
        mv -f "$X" "$BAK_DIR_PUB/$F" 2>/dev/null
    fi
    checkSumFile "$BAK_DIR_PUB/$F"
    writeMetaData "$BAK_DIR_PUB/$F"
    readMetaData "$BAK_DIR_PUB/$F".meta
    fileLogger "$ok $L_OFFER do_moveXferZone() : $buffer"
    return $EXIT_SUCCESS
}

#
# Write the metadata of a file.
# Used by do_moveXferZone
# 
function writeMetaData()
{
    file="$1"
    if [ ! -f "$file" ]; then
        error "writeMetaData() file '$file' not found"
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
    fi
    mapfile -t META < "$metafile"
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
        unset META[0]; unset META[1]; unset META[2]
        echo "DATE: " $dateFile
    fi
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
    if [ $bUseLogger -eq 1 ]; then
        which logger >/dev/null 2>&1
        rc=$?
        if [ $rc -ne 0 ]; then
            fileLogger "sorry, can't use logger"
            bUseLogger=0
        fi
    fi    

    if [ "x$BAK_DIR" = "x" ]; then
        fileLogger "BAK_DIR not defined: how can it be possible?"
        exit 123
    fi
    if [ "x$BAK_DIR_PUB" = "x" ]; then
        fileLogger "BAK_DIR_PUB not defined: set to BAK_DIR=$BAK_DIR"
        #echo "BAK_DIR_PUB not defined: set to BAK_DIR=$BAK_DIR"
        BAK_DIR_PUB=$BAK_DIR
    fi

    if [ "x$BAK_DIR_PUB" = "x$BAK_DIR" ]; then
        fileLogger "$WARN BAK_DIR_PUB and BAK__DIR are the same, this a bad idea"
    fi
    if [ "x$BAK_DIR_PUB" = "x$BAK_DIR" ]; then
        fileLogger "$WARN BAK_DIR_PUB and BAK__DIR are the same, this a bad idea"
    fi



    mkdir -p $BAK_DIR $BAK_DIR_PUB
    chmod 700 $BAK_DIR
    chmod a+rx $BAK_DIR_PUB 2>/dev/null

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

    if [ ! -f "$LOG_FILE" ]; then
        echo "new log file ($date)" > $LOG_FILE
        chmod o-rwx $LOG_FILE
    fi

    if [ ! -f "$ERR_FILE" ]; then
        echo "no such ERR_FILE=$ERR_FILE $(date) " > $ERR_FILE
        chmod o-rwx $ERR_FILE
    fi
    if [ "x$ZIP_PASSWD" = "x" ]; then
        fileLogger "ZIP_PASSWD is not defined... default value"
        ZIP_PASSWD="NeverForgetToSetAPassowrd"
    fi

}

function check_client_variables()
{
    ZIP_PASSWD=${ZIP_PASSWD:-"NoPassUsedButControlledAnyway"}
    mkdir -p $LTS_DIR
    chmod a+rx $LTS_DIR

    if [ ! -f "$LOG_FILE" ]; then
        echo "new log file ($date)" > $LOG_FILE
        chmod o-rwx $LOG_FILE
    fi
    
    if [ ! -f "$ERR_FILE" ]; then
        echo "no such ERR_FILE=$ERR_FILE $(date) " > $ERR_FILE
        chmod o-rwx $ERR_FILE
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
    echo "[DEBUG=$DEBUG]"

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
