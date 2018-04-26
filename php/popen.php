<?php
$file = popen("/bin/ls", 'r');
while (!feof($file))
{
    echo fgets($file);
}
pclose($file);
?>
