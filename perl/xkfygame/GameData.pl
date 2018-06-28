#! /usr/bin/perl
# 生成《侠客风云传前传》存档修改器所需的 GameData.txt
# 从 mod 文件中提取相关名字（关联ID）信息，便于人工阅读
#
# 注意：原版mod txt 很可能是 u16 编码，本脚本似乎只能正确处理 utf-8 文件
# 请先转码
# 可用 vim set fileenconding=utf-8 转
# 道具文件有的没标题行，第一行道具ID仍保存两字节头，手动删除

use strict;
use warnings;

# 角色
my (@roles, @weapontype);

# 道具分类：1武器 2护甲 3饰品 4药品 5任务 6秘籍
my (@weapon, @armor, @accessory, @drug, @task, @book);

# 天赋 内功 武功
my (@talent, @neigong, @routine);

my $fhmod;
my (@fields);

## 道具文件解析 ItemData.txt
open($fhmod, '<', 'ItemData.txt') or die $!;
while (<$fhmod>) {
	chomp;
	@fields = split(/\t/, $_);
	my $itemid = $fields[0];
	my $itemname = $fields[1];
	my $itemtype = $fields[2];

	next unless (defined($itemtype));
	# print "$itemid\t$itemname\t$itemtype\n";
	# next;

	if ($itemtype == 1) {
		push(@weapon, "$itemid\t$itemname");
	} elsif ($itemtype == 2) {
		push(@armor, "$itemid\t$itemname");
	} elsif ($itemtype == 3) {
		push(@accessory, "$itemid\t$itemname");
	} elsif ($itemtype == 4) {
		push(@drug, "$itemid\t$itemname");
	} elsif ($itemtype == 5) {
		push(@task, "$itemid\t$itemname");
	} elsif ($itemtype == 6) {
		push(@book, "$itemid\t$itemname");
	} else {
		print STDERR "ignore unknow item type $itemtype!";
	}
}
close($fhmod);

# exit;

## 角色文件解析 NpcData.txt
open($fhmod, '<', 'NpcData.txt');
while (<$fhmod>) {
	chomp;
	@fields = split(/\t/, $_);
	my $id = $fields[0];
	my $name = $fields[7];
	next unless (defined($name));
	if ($id =~ /^\d+/) {
		push(@roles, "$id\t$name");
	}
}
close($fhmod);

## 内功文件解析 NeigongData.txt
open($fhmod, '<', 'NeigongData.txt');
while (<$fhmod>) {
	chomp;
	@fields = split(/\t/, $_);
	my $id = $fields[0];
	my $name = $fields[1];
	next unless (defined($name));
	if ($id =~ /^\d+/) {
		push(@neigong, "$id\t$name\t0");
	}
}
close($fhmod);

## 武功文件解析 RoutineNewData.txt
open($fhmod, '<', 'RoutineNewData.txt');
while (<$fhmod>) {
	chomp;
	@fields = split(/\t/, $_);
	my $id = $fields[0];
	my $name = $fields[1];
	next unless (defined($name));
	if ($id =~ /^\d+/) {
		push(@routine, "$id\t$name\t0");
	}
}
close($fhmod);

## 天赋文件解析 TalentNewData.txt
open($fhmod, '<', 'TalentNewData.txt');
while (<$fhmod>) {
	chomp;
	@fields = split(/\t/, $_);
	my $id = $fields[0];
	my $name = $fields[1];
	next unless (defined($name));
	if ($id =~ /^\d+/) {
		push(@talent, "$id\t$name");
	}
}
close($fhmod);

## 武器类型几乎固定的
push(@weapontype, "1\t剑");
push(@weapontype, "2\t刀");
push(@weapontype, "3\t箭");
push(@weapontype, "4\t拳");
push(@weapontype, "5\t气");
push(@weapontype, "6\t索");
push(@weapontype, "7\t鞭");
push(@weapontype, "8\t棍");

## 输出部分
# 至标准输出，保存用重定向
print "[Roles]\n";
foreach my $item (@roles) {
	print "$item\n";
}
print "[Item-Weapon]\n";
foreach my $item (@weapon) {
	print "$item\n";
}
print "[Item-Armor]\n";
foreach my $item (@armor) {
	print "$item\n";
}
print "[Item-Accessory]\n";
foreach my $item (@accessory) {
	print "$item\n";
}
print "[Item-Drug]\n";
foreach my $item (@drug) {
	print "$item\n";
}
print "[Item-Task]\n";
foreach my $item (@task) {
	print "$item\n";
}
print "[Item-Book]\n";
foreach my $item (@book) {
	print "$item\n";
}
print "[Talent]\n";
foreach my $item (@talent) {
	print "$item\n";
}
print "[Neigong]\n";
foreach my $item (@neigong) {
	print "$item\n";
}
print "[Routine]\n";
foreach my $item (@routine) {
	print "$item\n";
}
print "[WeaponType]\n";
foreach my $item (@weapontype) {
	print "$item\n";
}
print "[End]\n";

