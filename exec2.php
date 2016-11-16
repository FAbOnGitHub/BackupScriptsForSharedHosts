<?php
/**
 *  exec2.php
 *  Hack FAb
 *  Exécution des scripts d'archivage du site. Affichage d'informations de
 *  déboguage

 */

if(! isset($_SERVER))
  die('$_SERVER is not set');


$path= dirname($_SERVER['SCRIPT_FILENAME']);

$sWarning = '';
if( ini_get('safe_mode') )
{
  $sWarning = "<p style='font-style: bold;'> Warning : safe_mode detected</p>";
}
echo <<<EOD
<html>
  <head>
    <title>Ex&eacute;cution scripts sauvegarde</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
  </head>
  <body>
$sWarning
EOD;

$LOG_FILE = $path.'/../www/log.txt';
$LOG = ' 1>>'.$LOG_FILE.' 2>>'.$LOG_FILE;
echo "$path<br />log: $LOG_FILE<hr />";

$action = 'all';
if(isset($_GET['action']) && $_GET['action'])
  $action = $_GET['action'];


switch($action)
  {
  case 'hostname':
    define('BAK_CMD', '/bin/hostname -s '.$LOG); //FAb's
    break;
  case 'host':
    define('BAK_CMD', '/bin/hostname -s '); //FAb's
    break;
  case 'phpiinfo':  //Faute volontaire
    phpinfo();
    break;
  case 'ls':
    define('BAK_CMD', "/bin/ls -al $path/ $path/../www/backup_*/");
    break;
  case 'check':
    $cmd = '/bin/bash '.$path.'/fix_fs.sh'; //FAb's
    echo '<pre>';
    echoExecShell($cmd);
    echo '</pre>';
    exit(0);
    break;


  case 'web':
    define('BAK_CMD', $path.'/backup_web.sh '.$LOG.';');
    break;
  case 'wiki':
    define('BAK_CMD', $path.'/backup_wiki.sh'.$LOG.';');
    break;
  case 'sql':
    define('BAK_CMD', $path.'/backup_sql.sh'.$LOG.';');
    break;
  case 'mysql':
    define('BAK_CMD', $path.'/backup_mysql_full.sh'.$LOG.';');
    break;

  case 'safe': //all
    define('BAK_CMD', "/bin/bash $path/backup_web.sh 2>>$LOG_FILE ;"
           ."/bin/bash  $path/backup_wiki.sh 2>>$LOG_FILE ;"
           ."/bin/bash  $path/backup_sql.sh 2>>$LOG_FILE ;");
    break;

  default: //n0thing! Use sage instead     
      #define('BAK_CMD', '~/cgi-bin/backup_web.sh; ~/cgi-bin/backup_wiki.sh; ~/cgi-bin/backup_sql.sh;'.$LOG);
    break;
  }

//define('BAK_CMD', '~/cgi-bin/backup_web.sh; ~/cgi-bin/backup_wiki.sh; ~/cgi-bin/backup_sql.sh;');
define('LOG_CMD', 'tail -20 $path/www/log.txt;');
define('LST_CMD', 'ls -al ~/www/backup_LH5Y59v');

// Adapte la sortie d'une commande shell

function echoShellOutput($text) {
  foreach($text as $line)
    echo htmlSpecialChars($line) . '<br />';
}

function echoExecShell($sCmd)
{
  $iRetCode = 0;
  $output=array();
  $sTitle = array('cmd: '.$sCmd);
  echo echoShellOutput($sTitle);
  exec($sCmd, $output, $iRetCode);
  $output[] = "--> $? = $iRetCode";
  echo echoShellOutput($output);

}


echo <<<EOD
<pre>
<b>Ex&eacute;cution backup...</b>
EOD;

echoExecShell(BAK_CMD);

echo <<<EOD
<br />
<b>Extrait journal www/log.txt</b>

EOD;

echoExecShell(LOG_CMD);
echo <<<EOD
<br />
<b>Listing www/backup</b>
EOD;
echoExecShell(LST_CMD);

echo <<<EOD
</pre>

  </body>
</html>
EOD;

?>