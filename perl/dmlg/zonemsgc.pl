#! /usr/bin/perl
# 提取 proto_cs_xxx.h 协议文件中定义的消息 CMD_REQ
# 生成回调函数定义片断
#
# 输入模式示例：
#define CS_CMD_HORSE_BASIC_REQ                   	11001 	/* 坐骑基础信息请求命令 */
# 
# 输出模式示例：
# ZoneMsgReg(CS_CMD_GUILD_CREATE_REQ, HandleGuildCreateReq);
# static int HandleGuildCreateReq(CPlayer* pPlayer, int iCmdID, char* pPkgBody, int iBodyLen)
# {
#	ASSERT_RET(pPlayer, -1);
# 	ASSERT_RET(pPkgBody, -1);
# 	tagCSGuildCreateRes stResBody;
# 	bzero(&stResBody, sizeof(stResBody));
# 	tagCSGuildCreateReq * pReqBody = (tagCSGuildCreateReq *)pPkgBody;
#
# 	CMsgMgr::Send2Client(CS_CMD_GUILD_CREATE_RES, &stResBody, sizeof(stResBody), pPlayer);
# 	return OK;
# }
#
# 输出结果：
# 对每一个 REQ 消息 ID，生成回调函数基本模板，并在上行生成注释块；
# 注册函数 Reg 调用语句列在最末，但须手动放在合适的初始化函数中。
#
# 用法：
# 采用标准输入输出
#   zonemsgc.pl < proto_cs_xxx.h [> tmp.cpp]
# 在 vim 中须选定部分行过滤 (全文也要在 ! 加 range，或先先定全文）
#   :'<,'>! macronum.pl
#
# Author: tan.sin.log@2016
#
use strict;
use warnings;

my $cmd = "";
my $cmdid = 0;
my $cmt = "";
my $cmdreq = "";
my $cmdres = "";
my $name = "";
my @regs = ();

while (<STDIN>) {
	if (/^\s*#define\s+CS_CMD_(\w+)_REQ\s+(\d+)\s*\/\*\s*(.*)\s*\*\//) {
		$cmd = $1;
		$cmdid = $2;
		$cmt = $3;
		$cmdreq = "CS_CMD_${cmd}_REQ";
		$cmdres = "CS_CMD_${cmd}_RES";
		$name = $cmd;
		$name =~ s/([A-Z])([A-Z]+)_?/\u$1\L$2\E/g;

		push(@regs, "ZoneMsgReg($cmdreq, Handle${name}Req);");
		&output;
	}
}
print(join("\n", @regs));
print "\n";

sub output {
	print <<EOF;
/* $cmt [$cmdid]
ZoneMsgReg($cmdreq, Handle${name}Req);
*/
static int Handle${name}Req(CPlayer* pPlayer, int iCmdID, char* pPkgBody, int iBodyLen)
{
	ASSERT_RET(pPlayer, -1);
	ASSERT_RET(pPkgBody, -1);
	tagCS${name}Res stResBody;
	bzero(&stResBody, sizeof(stResBody));
	tagCS${name}Req * pReqBody = (tagCS${name}Req *)pPkgBody;

	return CMsgMgr::Send2Client($cmdres, &stResBody, sizeof(stResBody), pPlayer);
}

EOF
}

