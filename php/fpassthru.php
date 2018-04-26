<?php
$file = fopen('db.php', 'r');
fgets($file);
echo fpassthru($file);
fclose($file);
?>
