# BackupScriptsForSharedHosts  # ;-\*- mode: org -\*-

*(French version below)*

## Genesis and aim of the project

Collection of tools to perform backups (mysql, svn, fs) and exfiltrate them.
This project has been initiated to backup the forum and the wiki of an hiking
association. Some features has been added to make tools less specific.

It is currently in production (july 2016). Feel free  to fork the project  or contribue to
it.

On july, 2016 the project migrated to GitHub (losing subversion history).

### General : how it works :

When you need to  backup a server `HOST A` (where you're  not root), you cas
use the scripts which starts which  `backup_` via a crontab. Then they build
archives and put them in a pseudo public area.

In a second time, another machine `HOST B` can connect to this pseudo public
aera in HTTPS and retrieve archives : see `import_backup2.sh` 

### What can be saved ?

1.  Crontab

    The crontab used to schedule backups :-)

2.  MySQL

    MySQL databases via a full dump of each schema or  some specific ones

3.  Subversion

    Scan  a directory  containing repositories  and perform  a dump  foreach of
    them. 

4.  Filesystem

    The   forum  (`www`)   and   the  wiki   (`wiki`)   use  specific   scripts
    (`backup_wiki.sh` and `backup_web.sh`) but it's quite easy to adapt to your
    needs.

### Configuration

Currently  a  lot  of  things  are  explained  (*in  french*)  in  the  file
`config.txt`).

But, fortunetly, config file `config_ovh.sh` is widely commented.

Scripts (HOST A= can use three level of configuration file :

1.  First `config_ovh.sh` in `cgi-bin` (default param)
2.  `config_priv.sh` in `cgi=etc`  (your param)
3.  `config_<hostname>.sh in =cgi=etc`  (option)

Host B which hosts `import_backup2.sh` use this file in addition :
`config_<hostname>_dist.sh in =cgi=etc`

nota : <hostname> is the result of bash command "hostname -s"

### Extra features :

-   Server Host A can  ask to retrieve additional files unknown  of host B via
    the file "Please<sub>backup.lst</sub>"
-   nearly every thing is logged
-   script to check configuration is provided
-   Long Term Support directory for imported archives : archives are retrieved
    and stored  by day except  that you can  specify a day  to push them  in a
    non-overwritten directory.

### What about security ?

-   Every step is logged into a log file.

-   Archives  are accessible  via an  unknown  URL (pseudo  public) and  realm
    password. But you should use SSL too if you can.

-   All archives are cyphered but default : All dumps are written to a private
    directory. Then  there are compressed  with zip  and a password  (which is
    weack) or if it's possible via gnupg (much stronger)

Indeed, it comes with no garanties :-)

## French version : en Français

Ce projet regroupe un ensemble  d'outils pour permettre faire des sauvegardes
d'un serveur  où on  n'est pas admin  (root) et de  les récupérer  depuis une
autre machine pour avoir une copie physique ailleurs.

À la base il s'agissait de sauvegarder  de manière fiable le forum et le wiki
d'une association hébergés sur une machine mutualisée chez l'hébergeur OVH.

Des fonctionnalités ont  été ajoutées pour permettre  de sauvegarder d'autres
objets pour d'autres cas.
