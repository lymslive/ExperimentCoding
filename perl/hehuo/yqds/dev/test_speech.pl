#!/usr/bin/env perl

require "../Speech.pm";
$Speech::DEBUG = 1;

my $file = shift;

my $token = '24.f5e652cecfcf9001f7ea774fd6077806.2592000.1553579839.282335-15270466';
# my $token = shift || Speech::get_token();
print "token: $token\n";

my $text = Speech::speech($token, $file);
print "text: $text\n";
