#! /usr/bin/perl

use strict;
use warnings;

my @nums;
my %file;

while(<>)
{
    chomp;
    next unless /xgame_1_(\d+)_bin_pos.txt/;
    push @nums, $1;
    $file{$1} = $_;
}

foreach my $n (sort { $a <=> $b } @nums)
{
    print "$file{$n}\n";
}

__END__
用于将文件名列表中按中间的数字排序
其实可用 sort 单行命令
ls *.txt |cat | sort -t "_" -k 3 -g
-------------------
