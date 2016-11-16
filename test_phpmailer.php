<?php

include 'mail_params.php';


    
$sPathMailer = "../PHPMailer";
set_include_path(get_include_path() . PATH_SEPARATOR . $sPathMailer);
set_include_path(
    get_include_path()
    . PATH_SEPARATOR
    . getenv('HOME') . '/fab/PHPMailer'
);

$sAutoLoad = 'PHPMailerAutoload.php';

require'PHPMailerAutoload.php';
//require $sPathMailer.'/class.phpmailer.php';


/**
 *
 */
function actionMails($sHost, $iPort, $sTo, $sFrom, $sReplyTo, $sBody)
{
    $mail = new PHPMailer;

    // Enable verbose debug output
    $mail->SMTPDebug = 3;
    // Set mailer to use SMTP
    $mail->isSMTP();
    // Specify main and backup SMTP servers
    $mail->Host = $sHost;
    // Enable SMTP authentication
    // $mail->SMTPAuth = true;
    $mail->SMTPAuth = false;
    // SMTP username
    $mail->Username = 'user@example.com';
    $mail->Username = '';
    // SMTP password
    $mail->Password = 'secret';                           
    // Enable TLS encryption, ssl also accepted
    //$mail->SMTPSecure = 'tls';

    // TCP port to connect to
    $mail->Port = $iPort;

    $mail->setFrom($sFrom, 'Mr Test');
    $mail->addAddress($sTo, 'Joe User');     // Add a recipient

    $mail->addReplyTo($sReplyTo, 'Information');

    //$mail->addAttachment('/var/tmp/file.tar.gz');         // Add attachments
    //$mail->addAttachment('/tmp/image.jpg', 'new.jpg');    // Optional name
    $mail->isHTML(true);                                  // Set email format to HTML

    $mail->Subject = $sSubject;
    $mail->Body    = $sBody;
    $mail->AltBody = 'This is the body in plain text for non-HTML mail clients';

    if (!$mail->send()) {
        echo 'Message could not be sent.';
        echo 'Mailer Error: ' . $mail->ErrorInfo;
    } else {
        echo 'Message has been sent';
    }
}


foreach ($aHosts as $h) {
    foreach ($aPorts as $p) {
        echo "<h2> $h:$p </h2>";
        echo "<pre>\n";
        actionMails($h, $p, $sTo, $sFrom, $sReplyTo, $sBody);        
        echo "</pre>";
        sleep(1);
    }   
}
    
?>