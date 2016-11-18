#!/usr/bin/env php
<?php


include 'mail_params.php';


$headers = "From: $sFrom\n";
$headers .= "Reply-To: $sReplyTo\n";
$headers .='Content-Type: text/plain; charset="iso-8859-1"'."\n";
$headers .='Content-Transfer-Encoding: 8bit';
mail($sTo,
         'Sujet', 
         'Message contenu de l email',
         $headers); 

?>