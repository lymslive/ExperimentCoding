#!/bin/bash

wget -O $1 "https://www.bannixuexi.com/cgi-bin/download.pl?proj=yqds_ga&fid=$1"
mv $1 $1.wav
