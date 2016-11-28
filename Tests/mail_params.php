<?php

$sFrom = "postmaster@randonner-leger.org";
$sReplyTo = "fab@blandineetfab.fr";
$sTo = "fab@blandineetfab.fr";
$sSubject = "Sujet du mail de test";
$sBody = "Corps du message";


$sHost = "localhost";
//$sHost = "119.mail-out.ovh.net";
//$sHost = "smtpauth.u-bordeaux.fr";
$sHost = '213.186.33.2';
//$sHost = '127.0.0.1';
$iPort = 25;

$aHosts = array(
    '127.0.0.1', '213.186.33.2', '119.mail-out.ovh.net'
);
$aPorts = array(25, 587);

?>