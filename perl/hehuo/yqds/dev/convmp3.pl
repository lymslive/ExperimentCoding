#! /usr/bin/env perl
package convmp3;
use strict;
use warnings;

use Audio::ConvTools;

my $audio_file = shift or die 'expect *.mp3 file as argument';
my $status = mp32wav($audio_file);
print "convert done: $status\n";
