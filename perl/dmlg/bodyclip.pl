#! /usr/bin/perl

# convert proto_struct to CSPkgBogy entry, like the following:
#
# <struct name="CSHuangtingDataReq" version="1" id="CS_CMD_HUANGTING_DATA_REQ" desc="黄庭数据请求">
# <entry name="HuangtingDataReq" type="CSHuangtingDataReq" id="CS_CMD_HUANGTING_DATA_REQ" desc="皇庭数据请求" />
#
# this perl script use stdin and stdout,
# so using direct operation (<in-file >out-file) if needed
# or combine with pipe (|)
while (<>) {
	if (/^\s*<struct name="([\w_]+)" id="([\w_]+)" version="\d+" desc="(.*)"\s*>/){
		my $name = $1;
		my $type = $1;
		my $id = $2;
		my $desc = $3;
		# $desc = " ";
		$name =~ s/^CS//;
		print("<entry name=\"$name\" type=\"$type\" id=\"$id\" desc=\"$desc\"/>\n");
	}
}
