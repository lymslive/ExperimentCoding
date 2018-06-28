#! /usr/bin/env perl
# http://bbs.chinaunix.net/thread-4172818-1-1.html
# 生成.clang_complete，可以用来很容易地添加include目录
# 使用的时候，需要把这个脚本放到自己home的.bin里面
# 然后设定vim不自动更换当前目录（set noacd）

use v5.14;

use Cwd;
use File::Find::Rule;

my $current_dir      = getcwd();
my @dir_array        = ();
my $config_file_name = ".clang_complete";
my $cmd              = "";

@dir_array = File::Find::Rule->directory->in("$current_dir");

$cmd = "rm -rf $config_file_name; touch $config_file_name;";
system($cmd);

foreach my $dir (@dir_array)
{
        $cmd = "echo -I$dir >> $config_file_name;";
	    system($cmd);
}

# 解读注释
#   let l:local_conf = findfile('.clang_complete', getcwd() . ',.;')
# clang_complete 插件查找 .clang_complete 可以向上递归，不需要 set noacd
