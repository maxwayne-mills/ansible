<?php
// Zabbix GUI configuration file
global $DB;

$DB['TYPE']     = 'MYSQL';
$DB['SERVER']   = 'localhost';
$DB['PORT']     = '3306';
$DB['DATABASE'] = 'zabbix';
$DB['USER']     = 'zabbix';
$DB['PASSWORD'] = 'qm7BD01alpCE';

// SCHEMA is relevant only for IBM_DB2 database
$DB['SCHEMA'] = '';

$ZBX_SERVER      = 'localhost';
$ZBX_SERVER_PORT = '10051';
// Change Open Site Solutions to what ever you want, this is displayed top left of the zabbix web interface
$ZBX_SERVER_NAME = 'Open Site Solutions';

$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG;
?>
