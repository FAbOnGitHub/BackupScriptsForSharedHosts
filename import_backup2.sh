#!/bin/bash
# import_backup.sh2  Meo, FAb & RL
#
# Importation de backups via wget. Rotation des backups sur la base de
# timestamps.
#
# Licence : GPL v3
#


#set -x
#  (À INCLURE) Chemin fichiers inclus, auto-ajustement
LIB_PATH=$(dirname $0)
. $LIB_PATH/boot.sh

FALSE=0
TRUE=1
let rc_default=999
let rc_error=666


###
# wgetFile : se charge de télécharger un ficher en loggant tout bien.
# $1 : le fichier à récupérer
# $2 : obligatoire (1 par défaut) ou pas (0)
function wgetFile()
{
    try=$TRUE
    ## Uncomment to debug and simulate download #hmm nope pb with metafile
    #try=$FALSE
    if [ $try -eq $FALSE ]; then
        rc_default=$EXIT_SUCCESS
        status="[-fake-]"
    fi
    
    debug "wgetFile(\$1=$1, \$2=$2)"
    target="$1"
    [ "x$target" = "x" ] && return $rc_error
    bRequired=$TRUE
    if [ "x$2" = "x" ]; then
	bRequired=$TRUE
	## echo "wgetFile() \$2='$2' vide->1 ($bRequired)"
    else
	bRequired="$2"
	## echo "wgetFile() \$2='$2' non vide donc valeur ($bRequired)"
    fi
    debug "wgetFile [taget=$target][bRequired=$bRequired]"

    if [ -f $BAK_DIR_CLI/$target ]; then
        mv -f $BAK_DIR_CLI/$target $BAK_DIR_CLI/$target.orig
    fi

    [ $VERBOSE -eq 1 ] && wget_quiet='' || wget_quiet="-q"
    #debug "wget $target..."
    rc=$rc_default
    let count=1
    while [ $try -eq $TRUE -a $count -le 3 ]
    do
        sWgetMsg=""
        wget $wget_quiet -t 3 --no-check-certificate --auth-no-challenge \
             -U $HTTP_AGENT \
             -P $BAK_DIR_CLI "$BAK_URL/$target" 2>> $ERR_FILE
        rc=$?
        # Ne pas activer la ligne suivante en prod ou penser à purger les log
        #debug "wget $BAK_URL/$target -> $BAK_DIR_CLI (rc=$rc)(errfile=$ERR_FILE)"
        if [ $rc -eq $EXIT_SUCCESS ]; then
            status="$ok"
            try=$FALSE
        elif [ $bRequired -eq 0 ]; then
            status="$WARN"
            sWgetMsg=":"$(wget_translate_error $rc )                        
            sWgetMsg="$sWgetMsg:optional file missing"
	    rc=$rc_default
	else
            status="$KO"
            sWgetMsg=":"$(wget_translate_error $rc )
        fi
        let count++
    done
    #echo "sWgetMsg=$sWgetMsg"
    fileLogger "$status wget $target (rc=${rc}${sWgetMsg}) (try: $count/3)"
    debug " wgetFile(): fin wget($rc) $LOG_URL/$target"
    return $rc
}

##
#  Fait les contrôles d'intégrité sur le fichier téléchargé dans BAK_DIR_CLI
#
function check_downloaded_file()
{
    file="$1"

    wgetFile "$file.csum"
    rc=$?
    if [ $rc -ne $EXIT_SUCCESS ]; then
        fileLogger "$KO wget CRC failed ($rc). Skip checks"
        hasFailed
        return $EXIT_FAILURE
    fi
    
    wgetFile "$file.meta" 0
    rc=$?
    if [ $rc -ne $EXIT_SUCCESS ]; then
        fileLogger "$WARN ${file}.meta wget metafile failed ($rc)(future feature)"
    else
        readMetaData "$BAK_DIR_CLI/$file.meta"
        rc=$?
        if [ $rc -ne $EXIT_SUCCESS -o  "x$epochFile" = "x" ]; then
            error " cannot read timestamp in metadata ! "
            hasFailed
            return $EXIT_FAILURE
        fi

        nowTS="$(LANG=C date +"%s")"
        distTS="$(LANC=C date --date="@""$epochFile" +"%F %T")"
        dateDiff -s "@""$nowTS" "@""$epochFile"
        delta=$dateDelta
        if [ $delta -gt $maxTime ]; then
            sMsg="$KO  $file too old (delta=$delta > max=$maxTime) $distTS"
            error $sMsg
            fileLogger $sMsg
        else
            fileLogger "$ok  age $file is not too old :  $distTS"
        fi
    fi
    


    servCsum=`head -n 1 $BAK_DIR_CLI/$file.csum 2>> $ERR_FILE`
    localCsum=`checkSum $BAK_DIR_CLI/$file 2>> $ERR_FILE`
    rm -f $BAK_DIR_CLI/$file.csum
    if [ "$localCsum" = "$servCsum" ]
    then
        size="$(du --si -s  $BAK_DIR_CLI/$file| awk '{print $1}')"
        fileLogger "$ok $file: CRC  ($size - $localSum crc)"
        SUCCESS=$TRUE
        debug "cksum valid ($file) $localCsum = $servCsum "
    else
        mv $BAK_DIR_CLI/$file $BAK_DIR_CLI/$ff.MAY_BE_CORRUPTED 2>> $ERR_FILE
        fileLogger  "$KO $file: CRC ERR ('$localCsum' vs '$servCsum')"
        hasFailed
        debug "cksum error ($file)"
        SUCCESS=$FALSE
        
        return $EXIT_FAILURE
    fi

    return $EXIT_SUCCESS
}

##
# Essaie de télécharger le fichier $sDistantBakFilename
# Si problème : ràs
# Si OK : ajout à la liste $BAK_FILES
function update_distant_list()
{
    fn="update_distant_list()"
    [ $bUseDistantBakFile -ne 1 ] && return $EXIT_FAILURE
    if [ "x$sDistantBakFilename" = "x" ]; then
        fileLogger "$fn: sDistantBakFilename is empty"
        return $EXIT_FAILURE
    fi

    rm -f $sDistantBakFilename
    bRequired=0
    wgetFile $sDistantBakFilename $bRequired
    rc=$?
    debug "update_distant_list() wget [rc:$rc]"
    if [ $rc -ne 0 ]; then
	return $rc
    fi
    if [ ! -f $BAK_DIR_CLI/$sDistantBakFilename ]; then
        fileLogger "$fn \$sDistantBakFilename(=$sDistantBakFilename) not found"
	return $FALSE
    fi
    aDistFiles=( $(sed -e "s@ @%20@g" -e "/^$/ d" $BAK_DIR_CLI/$sDistantBakFilename ) )
    BAK_FILES=( ${BAK_FILES[*]} ${aDistFiles[*]} )
    #BAK_FILES=( $BAK_FILES $aDistFiles )
    #echo "BAK_FILES="${BAK_FILES[*]}
}

# ###########################################################################
#
#         Main
#
# ###########################################################################
#set -x
DATE=$(date +"%Y%m%d-%H%M%S")
GENERAL_SUCCESS=$EXIT_SUCCESS

let maxTime=3600*28


# Normalement le client n'est pas obligé d'avoir la même arborescence que le
# serveur. Si c'est le cas, son répertoire BAK_DIR est BAK_DIR_CLI
## removed # [ "x$BAK_DIR_CLI" != "x" ] && BAK_DIR=$BAK_DIR_CLI
LTS_PATTERN=${LTS_PATTERN:-"4-Thu"}
TASK_NAME=${TASK_NAME:-"OutThere"}

if [ ! -d $BAK_DIR_CLI ]; then
    fileLogger  "$KO BAK_DIR_CLI ('$BAK_DIR_CLI') is missing"
    exit 1
fi
if [ ! -w $BAK_DIR_CLI ]; then
    fileLogger  "$KO BAK_DIR_CLI ('$BAK_DIR_CLI') is not writable"
    exit 1
fi
if [ ! -d $LTS_DIR ]; then
    fileLogger  "$KO LTS_DIR ('$LTS_DIR') is missing"
    exit 1
fi
if [ ! -w $LTS_DIR ]; then
    fileLogger  "$KO LTS_DIR ('$LTS_DIR') is not writable"
    exit 1
fi
if [ "x$BAK_URL" = "x" ]; then
    fileLogger  "\$BAK_URL is not set"
    exit 1    
fi

## URL à afficher dans log, sans le mot de passe
LOG_URL="$(echo "$BAK_URL"|cut -d'@' -f2-)"

# test
update_distant_list
#exit $?

# Main loop ###################################################################
declare -a aTmp=( ${BAK_FILES[*]} )
#let iNbTargetTotal=${#BAK_FILES[*]}  #bug
let iNbTargetTotal=${#aTmp[*]}
let iNbTargetOk=0

for raw_file in ${BAK_FILES[*]}; do

    #   echo "file=$file"
    # WTF ???
    file="$raw_file"
    try=$TRUE
    #  SUCCESS=$FALSE
    SUCCESS=$TRUE

    ff=$DATE-$file
    rm -f $BAK_DIR_CLI/$ff $BAK_DIR_CLI/$file.csum

    wgetFile $file
    rc=$?
    if [ $rc -ne $EXIT_SUCCESS ]; then
        fileLogger  "$KO wget file='$file' failed ($rc). Skip checks"
        hasFailed
        continue
    fi
    let iNbTargetOk++

    case $file in
        *.txt) bSkipCS=1 ;;
        *) bSkipCS=0           
           check_downloaded_file "$file"
           rc=$?
           SUCCESS=$rc
           ;;
    esac    

    if [ $SUCCESS -eq $EXIT_SUCCESS ]; then
        archive_downloaded_file "$file"
    else
        fileLogger "$WARN no global success for file '$file', so no rename '$day-'"
    fi

done

# Conclusion ##################################################################
#   Now distant log files must be passed in BAK_FILES

#
if [ $iNbTargetOk -eq $iNbTargetTotal ]; then
    sLabel="[ok]"
else
    sLabel="[KO]"
fi

logStop
reportByMail "$sLabel[$iNbTargetOk/$iNbTargetTotal] DL files"

exit $GENERAL_SUCCESS
