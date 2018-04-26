<?php
$servername = 'localhost:3306';
$username = 'root';
$password = '';

$con = mysql_connect($servername, $username, $password) or die('could not connect: '. mysql_error());

mysql_select_db('sgame_2_3');

$sql = 'SELECT * FROM DbChargeSuccLog WHERE RoleId=140174539879271639';
$result = mysql_query($sql, $con);
echo "seleced ret";
while ($row = mysql_fetch_array($result))
{
    echo $row;
}

mysql_close($con);
?>
