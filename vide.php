<?php
/**
 *  Inclure ce fichier dans un fichier index.php pour afficher une page vide 
 *  Les fichiers index.php servent alors que d'appelant.
 */

$sTitle =  isset($sTitle) &&$sTitle ? $sTitle : "Page vide";
$sBody = isset($sBody) && $sBody ? $sBody : "";

echo <<<EOD
<html>
<head>
 <title>$sTitle</title>
</head>
<body>
$sBody
</body>
EOD;

?>