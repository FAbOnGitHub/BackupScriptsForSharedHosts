# BackupScriptsForSharedHosts  # ;-\*- mode: org -\*-

*(French version below)*

## Aim of the project

Collection of tools to perform backups (mysql, svn, fs) and exfiltrate them.

### How it works :

When you need to  backup a server `HOST A` (where you're  not root), you cas
use the scripts which starts which  `backup_` via a crontab. Then they build
archives and put them in a pseudo public area.

In a second time, another machine `HOST B` can connect to this pseudo public
aera in HTTPS and retrieve archives.

## French version : en Français

Ce projet regroupe un ensemble  d'outils pour permettre faire des sauvegardes
d'un serveur  où on  n'est pas admin  (root) et de  les récupérer  depuis une
autre machine pour avoir une copie physique ailleurs.
