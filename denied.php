<?php
/**
 *  Inclure ce fichier dans un fichier index.php pour afficher un message
 *  d'accès interdit. Les fichiers index.php servent alors que d'appelant.
 */

//require_once("../fm_debug/fm_debug.inc.php");
$sBuffer = "Hello '".$_SERVER['REMOTE_ADDR']."', access denied. Data logged.";

$sTitle =  isset($sTitle) &&$sTitle ? $sTitle : "Access denied";
$sBody = isset($sBody) && $sBody ? $sBody : $sBuffer;


header("HTTP/1.0 403 Denied");


echo <<<EOD
<html>
<head>
 <title>$sTitle</title>
</head>
<body>
<h1>Access denied</h1>
$sBody
</body>
EOD;

die();
?>