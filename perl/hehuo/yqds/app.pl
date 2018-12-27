package XXX;
#  Leave the above package name as is, it will be replaced with project code when deployed.

use utf8;
use LWP::UserAgent;
use JSON;
use Digest::MD5  qw/ md5_hex /;
use Net::APNS::Persistent;
use XML::Simple;
use Data::Dumper;
use URI::Escape;
use Time::Format;

use Text::CSV_XS;
binmode(STDIN, ':encoding(utf8)');
binmode(STDOUT, ':encoding(utf8)');
binmode(STDERR, ':encoding(utf8)');
use Encode;
use Date::Parse;

################################################################################
#                                                                              #
#            SERVER INFO, PERSON REGISTERATION, LOGIN AND LOGOUT               #
#                                                                              #
################################################################################

# http post form submissiong, for image and file upload, client app shall include "proj" field
# the value of project code normally is included in the server_info hash
$UPLOAD_SERVERS="http://47.104.209.172/cgi-bin/upload.pl";

# __PACKAGE__ will be replaced with real project code when deployed. project code is used
# through out the development process. Each project has unique project code. There are 
# three variations of project code: proj, proj_la, proj_ga for development, limited 
# availability, and general availability respectively. _la version is for testing 
# and _ga is for production
$DOWN_SERVERS="http://47.104.209.172/cgi-bin/download.pl?proj=".lc(__PACKAGE__)."&fid=";

# fid for image where image is required but not provided by clients
# After image file is uploaded, a fid is returned. Client use fid where is required.
$DEFAULT_IMAGE = "f14686539620564930438001";

@numToChinese[21] = ("零","一","二","三","四","五","六","七","八","九","十","十一","十二","十三","十四","十五","十六","十七","十八","十九","二十");

sub server_info {
    
    #  server configuration data, to be passed down to client through p_server_info API call
    return {
    
        # project code this script is for
        proj => lc(__PACKAGE__),

        # file upload and download server address        
        upload_to => $UPLOAD_SERVERS,
        download_path => $DOWN_SERVERS,
        
        # App store or downloadable app version number. Client compares these version with
        # their own version to decide whether to prompt the user to update or not.
        android_app_version => 100,
        ios_app_version => 100,
        
        # configurable client ping intervals. Client SDK will ping server at these intervals
        android_app_ping => 180,
        ios_app_ping => 180,
        web_app_ping => 180,
		
		version_number => 1,
    };
}

$p_server_info = <<EOF;
system configuration data, all configuration data are stored on server

    Client apps use the configuration received through this interface.
    This api is called automatically on client SDK initialization.

EOF

sub p_server_info {
    return jr({server_info=>server_info()});
}

$p_person_get = <<EOF;
get pid of another person by login_name

INPUT:
	login_name:

OUTPUT:
	pid:
	avatar_fid:
	name:
EOF

sub p_person_get {

    my $account =mdb()->get_collection("account")->find_one({login_name => $gr->{login_name}});
	my $person = obj_read("person", $account->{pids}->{default});
    return jr({
		pid =>  $person->{_id},
		avatar_fid =>  $person->{avatar_fid},
		name =>  $person->{name},
	});
}

$p_person_chksess = <<EOF;
check session is still valid, normally this api is called by third party applications

EOF

sub p_person_chksess {
    return jr({ data => $gs->{pid} });
}

$p_person_register = <<EOF;
register an account

INPUT:
    display_name: J Smith name // displayed on screen   学生姓名
    login_name: jsmith // login name, normally a phone number
    login_passwd: 123 // login password
 
    data:{
        // other account and personal information
    }

	teacherCode:		教师号(只有学生端注册需要)
	school:				学校(只有学生端注册需要)
	grade:				年级(只有学生端注册需要)
	class:				班级(只有学生端注册需要)
	code:				验证码
	position:			职务(student/teacher)
	permission:			权限(mostAdmin/admin/user)(总管理员/学校管理员/普通用户),可不传,默认为普通用户

OUTPUT:
    user_info and server_info for successful registeration, and
    a valid session id

    server_info: {
    }

    user_info: {
    }
   
EOF

sub p_person_register {

    return jr() unless assert(length($gr->{login_name}), "login name not set", "ERR_LOGIN_NAME", "Login name not set");
	
	return jr() unless assert($gr->{position}, "position 参数缺少","position 参数缺少","position 参数缺少");
	
	my $display_name = "";
	if($gr->{position} eq "student"){
		return jr() unless assert(length($gr->{display_name}), "display name not set", "ERR_DISPLAY_NAME", "Display name not set");
	}
	
	if(length($gr->{display_name})){
		$display_name = $gr->{display_name};
	}
	else{
		$display_name = $gr->{login_name};
	}
		

	return jr() unless assert($gr->{code}, "code 参数缺少","code 参数缺少","code 参数缺少");
	
	my $vc = mdb()->get_collection("smsmessages")->find_one({phone=>$gr->{login_name}});
	
	if(!$vc){
		return jr() unless assert(0, "号码不存在","FAILED","号码不存在");
	}

	if((time - 300) > $vc->{last_message}->{et}){
		return jr() unless assert(0, "验证码已过期","FAILED","验证码已过期");
	};

	if($vc->{last_message}->{content} eq $gr->{code}){
		$vc->{messages_log}->{$vc->{last_message}->{et}} = $vc->{last_message};
		delete $vc->{last_message};
		#obj_write($vc);
	}
	else{
		return jr() unless assert(0, "验证码错误","FAILED","验证码错误");
	}
	
	
    my $p = $gr->{data};

    
    # Create an account record with login_name and login_passwd. It will return an associate person record
    # to store other person infomation.
    # $gr->{server} - The server where this api request is made.
    my $pref = account_create($gr->{server}, $display_name, "", $gr->{login_name}, $gr->{login_passwd});
    
    return jr() unless assert($pref, "account creation failed");
    
    # Store other data as-is in the person record.
    obj_expand($pref, $p);

    sess_server_create($pref);
    
    # Default avatar.
    #$pref->{avatar_fid} = $DEFAULT_IMAGE unless $pref->{avatar_fid};
	$pref->{avatar_fid} = "" unless $pref->{avatar_fid};
    $pref->{name} = $display_name;
	$pref->{login_name} = $gr->{login_name};
	
	#if($gr->{position} eq "teacher"){
	#	my $school = mdb()->get_collection("SchoolMember")->find_one({teacherCode=>$gr->{teacherCode}});
	#	$pref->{teacherCodeList}->{$gr->{teacherCode}} = $school->{_id};
	#}else{
	if($gr->{position} eq "student"){
		$pref->{teacherCode} = $gr->{teacherCode};
		$pref->{school} = $gr->{school};
		$pref->{grade} = $gr->{grade};
		$pref->{class} = $gr->{class};
		
		my $schoolTmp = mdb()->get_collection("classMember")->find_one({teacherCode=>$gr->{teacherCode}});
		if($schoolTmp){
			$pref->{schoolId} = $schoolTmp->{_id};	
		}
	}
	
	if($gr->{position}){
		$pref->{position} = $gr->{position};
	}
	
	if(length($gr->{permission})){
		$pref->{permission} = $gr->{permission};
	}else{
		$pref->{permission} = "user";
	}
	
	obj_write($pref);
	
	{
		#客户临时测试使用,后期要删除
		my $order = {
			_id => obj_id(),
			type => 'order',
			studentId => $pref->{_id},
			booksId => "o15377041856745200157",
			bookName => "宝葫芦的秘密",
			bookFid => "f15377863915023128986001",
			category => "导读版",
			price => 160,
			Order_Status => "已完成",
			createTime => time(),
			PaymentBillId => "111111111111111111",
		};
		obj_write($order);
	}
    return jr({ user_info => $pref, server_info => server_info()});
}

sub adminAddPerson_add {
	my $login_name = $_[0];
	my $position = $_[1];
	
	my $display_name = "";
	if($position eq "student"){
		return jr() unless assert(length($login_name), "display name not set", "ERR_DISPLAY_NAME", "Display name not set");
	}
	
	if(length($gr->{display_name})){
		$display_name = $gr->{display_name};
	}
	else{
		$display_name = $login_name;
	}

    my $pref = account_create($gr->{server}, $display_name, "", $login_name, "123456");
    
    return jr() unless assert($pref, "account creation failed");
	
    #sess_server_create($pref);
    
	$pref->{avatar_fid} = "" unless $pref->{avatar_fid};
    $pref->{name} = "";
	$pref->{login_name} = $login_name;

	if($position){
		$pref->{position} = $position;
	}
	obj_write($pref);
	
    return{ personId => $pref->{_id}};
}

sub AddAdmin_add {
	my $count = scalar(@_);
	if($count != 5){
		return jr() unless assert(0, "参数错误", "参数错误", "参数错误");
	}
	
	my $login_name = $_[0];
	my $name = $_[1];
	my $sex = $_[2];
	my $position = $_[3];
	my $telephone = $_[4];
	my $password = "123456";

    my $pref = account_create($gr->{server}, $name, "", $login_name, $password);
    
    return jr() unless assert($pref, "account creation failed");
    
	my $p = {};
    obj_expand($pref, $p);

    sess_server_create($pref);
    
	$pref->{avatar_fid} = "" unless $pref->{avatar_fid};
    $pref->{name} = $name;
	$pref->{login_name} = $login_name;
	$pref->{telephone} = $telephone;
	$pref->{permission} = "admin";
	
	if($gr->{position}){
		$pref->{position} = $position;
	}
	obj_write($pref);
	
    return{ personId => $pref->{_id}};
}

$p_person_login = <<EOF;
person log into system

INPUT:
    // normal login with these two fields
    login_name: abc login name
    login_passwd: asc login password
    
	login_type:   student/teacher
    // extended login (loginx) with complex credentail data
    credential_data/0:{
        
        // [1] normal credentail data
        ctype: normal
        login_name: login name
        login_passwd: login password
    
        // [2] oauth2 credential data
        ctype: oauth2
        authorization_code: token from oauth api calls
    
        // [3] unique device id as credential data
        device_id: // mobile device ID, unique id
        ctype: device
        devicetoken: Apple device token
    
    }
	
    verbose/0: 0/1 if set to 1, return user_info and server_info
    // verbose: 1 - used for initial login; 0 - used to maintain connection when extra information not needed.

EOF
    
sub p_person_login {
    if ($gr->{credential_data} && $gr->{credential_data}->{ctype} eq "device") {
        
        return jr() unless assert(length($gr->{credential_data}->{device_id}), "device id not set", "ERR_LOGIN_DEVICE_IDING", "device id not set");        
        
        # check for device_id, login without password
        my $mcol = mdb()->get_collection("account");
        my $aref = $mcol->find_one({device_id => "device:".$gr->{credential_data}->{device_id}});
        
        if($gr->{client_info}->{clienttype} eq "iOS"){
            return jr({status=>"failed"}) unless assert(length($gr->{credential_data}->{devicetoken}), "devicetoken is missing", "ERR_DEVICE_TOKENING", "Apple devicetoken missing");
        }

        if ($aref) {

            # Personal record id. Personal record stores information related to a person other than account information.
            my $pref = obj_read("person", $aref->{pids}->{$gr->{server}});

			#if($gr->{login_type} ne $pref->{position}){
			#	return jr() unless assert(0,"账号错误","账号错误","账号错误");	
			#}
            # Create a session if login OK.
            sess_server_create($pref);

            if($gr->{credential_data}->{devicetoken}) {

                $pref->{devicetoken} = $gr->{credential_data}->{devicetoken};

            } else {
                delete $pref->{devicetoken};
            }

            $pref->{avatar_fid} = $DEFAULT_IMAGE unless $pref->{avatar_fid};

            obj_write($pref);

            return jr({ user_info => $pref, server_info => server_info()}) if $gr->{verbose};

            return jr();
        }

        my $pref = account_create($gr->{server}, "device:".$gr->{credential_data}->{device_id}, "device:".$gr->{credential_data}->{device_id});

        return jr() unless assert($pref, "account creation failed");

		#if($gr->{login_type} ne $pref->{position}){
		#	return jr() unless assert(0,"账号错误","账号错误","账号错误");	
		#}
			
        sess_server_create($pref);

        if($gr->{credential_data}->{devicetoken}){
             $pref->{devicetoken} = $gr->{credential_data}->{devicetoken};

        }else{
             delete $pref->{devicetoken};
        }

        $pref->{avatar_fid} = $DEFAULT_IMAGE unless $pref->{avatar_fid};

        obj_write($pref);

        return jr({ user_info => $pref, server_info => server_info()}) if $gr->{verbose};

        return jr();    
    }

    # One of these two flavor of credentials is accepted.
    my ($name, $pass) = ($gr->{login_name}, $gr->{login_passwd});
    ($name, $pass) = ($gr->{credential_data}->{login_name}, $gr->{credential_data}->{login_passwd}) unless $name;
    
    my $pref = account_login_with_credential($gr->{server}, $name, $pass);
    return jr() unless assert($pref, "登录失败", "ERR_LOGIN_FAILED", "登录失败");
    
    # Purge other login of the same login_name. Uncomment this if single login is enforced.
    #account_force_logout($pref->{_id});

	#{
	#	my $accountTmp =mdb()->get_collection("account")->find_one({login_name => $name});
	#	my $personTmp = obj_read("person", $accountTmp->{pids}->{default});
	#	if($gr->{login_type} ne $personTmp->{position}){
	#		return jr() unless assert(0,"账号错误","账号错误","账号错误");	
	#	}
	#}
	
	if(!length($pref->{permission}) or $pref->{permission} eq "user"){
		if($gr->{credential_data}->{login_type} ne $pref->{position}){
			assert(0,"账号错误","账号错误","账号错误");	
			return jr();
		}
	}
	
	#管理员和超级管理员,只允许单点登录
	#if ($gr->{verbose} and length($pref->{permission})){
	#	if($pref->{permission} eq "mostAdmin" or $pref->{permission} eq "admin"){
	#		account_force_logout($pref->{_id});
	#	}
	#}
	
    sess_server_create($pref);
    
    #$pref->{avatar_fid} = $DEFAULT_IMAGE unless $pref->{avatar_fid};

	$pref->{isParent} = "否";
	
    obj_write($pref);

	if($pref->{permission} eq "admin"){
		my $school = mdb()->get_collection("SchoolMember")->find_one({adminName=>$pref->{name}});
		
		if($school){
			$pref->{schoolId} = $school->{_id};
		}
	}
	
    return jr({ user_info => $pref, server_info => server_info()}) if $gr->{verbose};
    
    return jr();
}

$p_password_reset=<<EOF;
修改密码
输入:
	{
		"obj":"password",
		"act":"reset",
		"phone":"13316666621", //电话号码
		"password":"",
		"code":""
	}
EOF

sub p_password_reset{
	return jr() unless assert($gr->{phone}, "phone 参数缺少","phone 参数缺少","phone 参数缺少");
	return jr() unless assert($gr->{password}, "password 参数缺少","password 参数缺少","password 参数缺少");
	return jr() unless assert($gr->{code}, "code 参数缺少","code 参数缺少","code 参数缺少");
	
	my $vc = mdb()->get_collection("smsmessages")->find_one({phone=>$gr->{phone}});
	
	if(!$vc){
		return jr() unless assert(0, "号码不存在","FAILED","号码不存在");
	}

	if((time - 300) > $vc->{last_message}->{et}){
		return jr() unless assert(0, "验证码已过期","FAILED","验证码已过期");
	};

	if($vc->{last_message}->{content} eq $gr->{code}){
		$vc->{messages_log}->{$vc->{last_message}->{et}} = $vc->{last_message};
		delete $vc->{last_message};
		#obj_write($vc);
	}
	else{
		return jr() unless assert(0, "验证码错误","FAILED","验证码错误");
	}
	
	
	my $account = mdb()->get_collection("account")->find_one({login_name => $gr->{phone}});

	if(!$account){
		return jr() unless assert(0, "用户不存在","FAILED","用户不存在");
	}
	account_reset_passwd($account->{_id}, $gr->{password});
	
	return jr();
}

$p_passwordByOld_reset=<<EOF;
修改密码
输入:
	{
		"obj":"passwordByOld",
		"act":"reset",
		"login_name":"",
		"passwd_old":"",
		"password":""
	}
EOF

sub p_passwordByOld_reset{
	return jr() unless assert($gr->{passwd_old}, "passwd_old 参数缺少","passwd_old 参数缺少","passwd_old 参数缺少");
	return jr() unless assert($gr->{password}, "password 参数缺少","password 参数缺少","password 参数缺少");
	return jr() unless assert($gr->{login_name}, "login_name 参数缺少","login_name 参数缺少","login_name 参数缺少");
	
	my $account = mdb()->get_collection("account")->find_one({login_name => $gr->{login_name}});

	if(!$account){
		return jr() unless assert(0, "用户不存在","FAILED","用户不存在");
	}
	
	my $res = account_update_passwd($account->{_id}, $gr->{passwd_old}, $gr->{password});
	
	if($res == 0){
		return jr() unless assert(0, "原始密码错误","原始密码错误","原始密码错误");
	}
	
	return jr();
}

$p_person_getcode=<<EOF;
获取手机验证码 注册或修改
输入:
	{
		"obj":"person",
		"act":"getcode",
		"login_name":"",
		"xtype":"register"		注册或者修改密码(register/modify)
	}
输出:
	{
		sess: "", 
		io: "o", 
		obj: "person", 
		act: "getcode", 
	}
EOF

sub p_person_getcode{
	
	return jr() unless assert($gr->{phoneNo}, "phone num is missing","ERR_PHONENO_MISSING","电话号码缺少");
	return jr() unless assert($gr->{xtype} eq "register" || $gr->{xtype} eq "modify", "code type is missing","ERR_CODE_TYPE_MISSING","验证码类型缺少");
	
	#if ($gr->{xtype} eq "binding") {
	#	#判断已经有手机号
	#	if($person->{telephone_Number}){
	#		return jr() unless assert(0,"已绑定手机","ALREADY BOUND MOBILE PHONE","已绑定手机");
	#	}
	#
	#} elsif($gr->{xtype} eq "unbind"){
	#	#判断解绑手机号和当前用户信息中的手机号是否相符
	#	if($person->{telephone_Number} eq $gr->{phoneNo}){
	#		$person->{telephone_Number} = "";
	#		obj_write($person);
	#	}else{
	#		return jr() unless assert(0,"手机号错误","MOBILE_NUMBER_ERROR","手机号错误");
	#	}
	#	
	#}
	
	my $vc = mdb()->get_collection("smsmessages")->find_one({phone=>$gr->{phoneNo}});
	
	my $type = "";
	if($gr->{xtype} eq "register"){
		#判断手机号码是否已经被注册了
		my $accountTemp = mdb()->get_collection("account")->find_one({login_name=>$gr->{phoneNo}});
		return jr() unless assert(!$accountTemp,"phoneNo alerady register","ERR_ALERADY_REGISTER","号码".$gr->{phoneNo}."已被注册");
		
		$type = "SMS_138064758";
	}elsif($gr->{xtype} eq "modify"){
		my $accountTemp = mdb()->get_collection("account")->find_one({login_name=>$gr->{phoneNo}});
		return jr() unless assert($accountTemp,"phoneNo is not registered","ERR_NOT_REGISTERED","号码".$gr->{phoneNo}."还未注册");
		
		$type = "SMS_138069568";
	}
	
	#生成6位验证码
	my $code = int(rand(10)).int(rand(10)).int(rand(10)).int(rand(10)).int(rand(10)).int(rand(10)); 
	
	#发送短信(阿里云aliyun 帐号)
	my $result = `python /var/www/games/app/yqds/alicom-python-sdk-dysmsapi/send.py $gr->{phoneNo} $code $type 2>&1`;
	 
	#判段短信表中是否已经有记录了
	if (!$vc) {
		$vc = {
			_id => obj_id(),
			type => "smsmessages",
			phone => $gr->{phoneNo},
		};
	}
	
	if ($vc->{last_message}) {
		$vc->{messages_log}->{$vc->{last_message}->{et}} = $vc->{last_message};
		delete $vc->{last_message};
	}
	
	$vc->{last_message}->{content} = $code;
	$vc->{last_message}->{result} = $result;
	$vc->{last_message}->{xtype} = $gr->{xtype};
	$vc->{last_message}->{status} = "sent";
	$vc->{last_message}->{et} = time;
	
	#更新数据库中的验证码 
	obj_write($vc);
	
	# {"Message":"OK","RequestId":"6E7A8CE0-EB23-4BBC-BCFD-0EA075FBA368","BizId":"636210228523730271^0","Code":"OK"}
	assert(scalar($result =~ /"Message":"OK"/), "sms send error","ERR_SMS_SEND","sms send error");
	
	return jr({sms_result=>$result});
}

$p_person_checkcode=<<EOF;
校验手机验证码
输入:
{
	"obj":"person",
	"act":"checkcode",
	"phoneNo":"13225990571",	//手机号
	"code":"951991"			//验证码
}
输出:
{
    sess: "", 
    io: "o", 
    obj: "person", 
    act: "checkcode", 
    msg: "号码不存在", 		//失败才有msg
    status: "FAILED"		//成功为SUCCEED,失败FAILED
}
EOF

sub p_person_checkcode
{
	return jr() unless assert($gr->{phoneNo}, "phone num is missing","ERR_PHONENO_MISSING","电话号码缺少");
	return jr() unless assert($gr->{code}, "code 参数缺少","code 参数缺少","code 参数缺少");
	
	my $vc = mdb()->get_collection("smsmessages")->find_one({phone=>$gr->{phoneNo}});
	
	if(!$vc){
		return jr() unless assert(0, "号码不存在","FAILED","号码不存在");
	}

	if((time - 300) > $vc->{last_message}->{et}){
		return jr() unless assert(0, "验证码已过期","FAILED","验证码已过期");
	};

	if($vc->{last_message}->{content} eq $gr->{code}){
		$vc->{messages_log}->{$vc->{last_message}->{et}} = $vc->{last_message};
		delete $vc->{last_message};
		#obj_write($vc);
	}
	else{
		return jr() unless assert(0, "验证码错误","FAILED","验证码错误");
	}
}

$p_person_qr_get = <<EOF;
get the connection id to display on QR code login screen, normally called by webapp

OUTPUT:
    conn: // connection id

EOF

sub p_person_qr_get {
    return jr({ conn => $global_ngxconn });
}

$p_person_qr_login = <<EOF;
log in webapp by scanning QR code displayed on the webapp with mobile device

INPUT:
    conn: // connection id

OUTPUT:
    count: // how many qr login messages are sent

EOF

sub p_person_qr_login {

    return jr() unless assert($gr->{conn}, "connection id is missing");

    my $rt_sess = sess_server_clone($gr->{conn});

    my $pref = obj_read("person", $gs->{pid});

    $pref->{avatar_fid} = $DEFAULT_IMAGE unless $pref->{avatar_fid};

    obj_write($pref);

	# carry the sess with the data, flag 1
    my $rt_send = sendto_conn($gr->{conn}, {
        sess        => $rt_sess,
        io          => "o",
        obj         => "person",
        act         => "login",
        user_info   => $pref, 
        server_info => server_info(),
    }, 1);
    
    return jr({ count => $rt_send });
}

$p_person_logout = <<EOF;
log out of system
EOF
    
sub p_person_logout {
    
    sess_server_destroy();
    
    return jr();
}

################################################################################
#                                                                              #
#                   CONVERSATION AND MESSAGING RELATED CODE                    #
#                                                                              #
################################################################################

# To implement other forms of conversations, define a new header structure,
# "header" can be: chat(two person), group(more than two person), topic, ....
 
# push message format, and mailbox entry format, and implement message get and send api.
# Header structure shall at least contain a field named "block_id". 

$p_push_message_chat = <<EOF;
push notification: personal chat message received

    This is a notification sent from server. Not a callable api by client.

PUSH:
    obj              // push
    act              // message_chat
    mtype            // message type: text/image/voice/link/file ...
    content          // message content text, link, etc.
    time
    from_id          // sender person id
    from_name        // sender name
    from_avatar      // sender avatar fid
	
	header_id	     // from_id (person id) of this message 
EOF

sub p_push_message_chat {
    return jr() unless assert(0, "", "ERROR", "push data only, not a callable API");
}

$p_push_message_group = <<EOF;
push notification: group message received

    This is a notification sent from server. Not a callable api by client.

PUSH:
    obj              // push
    act              // message_group
    mtype            // message type: text/image/voice/link/file ...
    content          // message content text, link, etc.
    time
    from_id          // sender person id
    from_name        // sender name
    from_avatar      // sender avatar fid
	
	header_id	     // group id this message belongs to
EOF

sub p_push_message_group {
    return jr() unless assert(0, "", "ERROR", "push data only, not a callable API");
}

##############################################

$p_message_chat_send =<<EOF;
personal chat send. Client calls this api to send a message to the other party

INPUT:
    header_id":  "o14489513231729540824"   // to_id, person id of the other party (chat_id not used!)
	
    mtype:       "text",                   // message type: text/image/voice/link/file
    content:     "Hello"                   // message content text, link, etc.
		// mtype == image
		// content == {
		//		fid: larger image, return from upload.pl
		//		thumb: smaller image, return from upload.pl
		//		type: mime type, png/jpg/gif .. optional
		
OUTPUT:
    header_id: "o14489513231729540824",      // chat record id
    
EOF

sub p_message_chat_send {

    return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
    return jr() unless assert($gr->{header_id}, "header_id is missing", "ERR_TO_ID", "Chat partner person id is not specified.");

    return jr() unless assert($gs->{pid} ne $gr->{header_id}, "from_id header_id identical", "ERR_SEND_TO_SELF", "Sending chat to self is not supported.");
    
    # Chat header record is empty. Chat is just started. Create a record for this conversation.
    my $col = mdb()->get_collection("chat");
    
    # pair field consist of ordered two person id, is the key to find the chat header record.
    my $header = $col->find_one({pair => join(",",sort($gs->{pid}, $gr->{header_id}))});
    
    if(!$header) {

        $header->{_id} = obj_id();
        $header->{type} = "chat";
        $header->{pair} = join(",",sort($gs->{pid}, $gr->{header_id}));
        $header->{block_id} = 0;

        obj_write($header);
    }
    	
    my $header = obj_read("chat", $header->{_id});
	
	my @other_parties = ($gr->{header_id});
	
	my $rt = message_common_send($header, @other_parties);
	return $rt if ($rt);
	
	return jr({ 
		header_id => $gr->{header_id},
	});
}

$p_message_group_send =<<EOF;
group message send. Client calls this api to send a message to a group

INPUT:
    header_id":"o14489513231729540824"   // group record id
	
    mtype:       "text",                   // message type: text/image/voice/link/file
    content:     "Hello"                   // message content text, link, etc.
		// mtype == image
		// content == {
		//		fid: larger image, return from upload.pl
		//		thumb: smaller image, return from upload.pl
		//		type: mime type, png/jpg/gif .. optional
		

OUTPUT:
    header_id: "o14489513231729540824",      // group record id
    
EOF


sub p_message_group_send {

    return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
    return jr() unless assert($gr->{header_id}, "header_id is missing", "ERR_TO_ID", "Group id is not specified.");
    
   	my $header = obj_read("group", $gr->{header_id});
    
    if(!$header) {

        $header->{_id} = obj_id();
        $header->{type} = "group";
        $header->{members} = [];
        $header->{block_id} = 0;

        obj_write($header);
    }
    	
    my $header = obj_read("group", $header->{_id});
	
	my @other_parties = @{$header->{members}};
	
	my $rt = message_common_send($header, @other_parties);
	return $rt if ($rt);
	
	return jr({ 
		header_id => $header->{_id},
	});
}

sub message_common_send {

	my @other_parties = @_;
	
	# header - conversation specific header structure, holds block chain, as block_id the latest block
	
	# and other information:
	#
	# 	- title (group title, topic title, etc)
	#	- avatar_fid (group icon, topic icon, etc)
	#
	
	my $header = shift @other_parties;
	
    return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
    
    return jr() unless assert($gr->{content}, "content is missing", "ERR_CONTENT", "Message content is empty.");
    
    return jr() unless assert($gr->{mtype}, "mtype is missing", "ERR_MTYPE", "Message content type is not specified.");
    
    my $from_person = obj_read("person", $gs->{pid});
    
	# special case for chat, where header id is not chat record id, but pid of the other party
	my $header_id = $header->{_id};
	if ($header->{type} eq "chat") {
		$header_id = $gs->{pid};
	}
	
    my $message = {
        obj             => "push",
        act             => "message_".$header->{type},
        content         => $gr->{content},
        time            => time,
        mtype           => $gr->{mtype},
        from_id         => $gs->{pid},
        from_name       => $from_person->{name} || "Noname",
        from_avatar     => $from_person->{avatar_fid} || $DEFAULT_IMAGE_FID,
		header_id		=> $header_id,
    };
    
    $message->{from_avatar} = $DEFAULT_IMAGE_FID unless $message->{from_avatar};
    
    # Push this message to other parties. count - actuall message number sent
    # count may be more than one if there are more than one logins with the same account
    # $gr->{server} - same server where the request is coming from.
	
	my @ios_push = ();
	my @android_push = ();
	
	foreach my $p (@other_parties) {
	    my $count = sendto_pid($gr->{server}, $p, $message);  
	
	    # If none of them is online to receives message through our communication channel, push this
	    # message through third-party push notification mechanism.
	    if(!$count){
	    
	        my $person = obj_read("person", $p);
	        
	        # devicetoken stores the token needed for third-party push notification
	        # Client sends this token after it logins the system.
	        if($person->{devicetoken} && $person->{devicetype} eq "ios") {
				push @ios_push, $person->{devicetoken};
	        }
	    }
	}
	
	net_apns_batch($message, @ios_push);
	# TODO
	# android push notification
	
    # create new chat block record for new message or simply added to current block
    # chat data are stored with multiple chained blocks where each block stores maximum of 50
    # chat entries.
    return jr() unless add_new_message_entry($header, $gs->{pid}, $gr->{mtype}, $gr->{content});
	
	foreach my $p ($gs->{pid}, @other_parties) {
	
		if ($header->{type} eq "chat") {
			if ($p eq $gs->{pid}) {
				$header_id = $other_parties[0];
			} else {
				$header_id = $gs->{pid};
			}
		}
		
	    # Third param "2" will cause system to siliently create an obj of this type with specified id
	    # Obj is created as needed instead of assertion failure when obj is accessed before creation.
	    my $mailbox = obj_read("mailbox", $p, 2);
	    
	    # Add an entry in chat sender's message center as well.
	    $mailbox->{ut} = time;
	    $mailbox->{messages}->{$header_id}->{htype}  = $header->{type}; # conversation type
	    $mailbox->{messages}->{$header_id}->{hid}	 = $header->{_id};
	    $mailbox->{messages}->{$header_id}->{ut} 	= time;
	    $mailbox->{messages}->{$header_id}->{count} ++;
	    $mailbox->{messages}->{$header_id}->{block}  = $header->{block_id};
	    
	    # Generate label to display on their message center.
	    if ($gr->{mtype} eq "text") {
	        $mailbox->{messages}->{$header_id}->{last_content} = substr($gr->{content}, 0, 30);
	    } else {
	        $mailbox->{messages}->{$header_id}->{last_content} = "[".$gr->{mtype}."]";
	    }
	    
	    $mailbox->{messages}->{$header_id}->{last_avatar} = $from_person->{avatar_fid} || $DEFAULT_IMAGE_FID;
	    $mailbox->{messages}->{$header_id}->{last_name}   = $from_person->{name} || "Noname";
		
		# two person chat, special handling, make it easier for client programming
		if ($header->{type} eq "chat") {
		
			# store the other party only as title of the conversation
			my ($id1, $id2) = split /,/, $header->{pair};
			my $person = $id1;
			$person = $id2 if $person eq $p;
			my $pref = obj_read("person", $person);
			
	    	$mailbox->{messages}->{$header_id}->{title} 	= $pref->{name} || "Noname";
	    	$mailbox->{messages}->{$header_id}->{avatar_fid}= $pref->{avatar_fid} || $DEFAULT_IMAGE_FID;
	    	$mailbox->{messages}->{$header_id}->{id}     	= $person;
			
	    } else {
		
	    	# generic header has these two fields
			$mailbox->{messages}->{$header_id}->{title} = $header->{title};
	    	$mailbox->{messages}->{$header_id}->{avatar_fid} = $header->{avatar_fid};
		}
		
	    obj_write($mailbox);
	}
    
    return undef;
}

##############################################

$p_message_chat_get =<<EOF;
retrieve personal chat, get a list of chat content entries

INPUT:
    header_id: // the other party id, get the first block
    block_id: // OR: to request next block of chat entries, use the block id from the last block record

OUTPUT:
    block: {
        _id: "o14489513231757400035", 
        next_id: 0,
        
        entries: [
        
        {
            content:    "Hello?",                    // message content
            from_name:  "Tom",                       // sender name
            from_avatar:"f14477630553830869196",     // sender avatar
            send_time:  1448955461,                  // send timestamp
            sender_pid: "o14477397324317851066",     // sender pid
            mtype:      "text"                       // message type: text/image/voice/link/file
        },
        
        {
            content:    "Hi, whats up", 
            from_name:  "Smith",
            from_avatar:"f14477630553830869190", 
            send_time:  1448955486, 
            sender_pid: "o14477630553830869197", 
            mtype:      "text"
        },
        
        {
            content:    "Jane", 
            from_avatar: "f14477630553830869192", 
            send_time:  1448956085, 
            sender_pid: "o14477397324317851066", 
            mtype:      "text"
        }
        
        ],
        
        type: "messages_block"
    }
    
EOF

sub p_message_chat_get {

    # $gs stores the data for this login session. It contains pid of the api caller.
    return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
    if($gr->{header_id}){
    
    	my $col = mdb()->get_collection("chat");
		
        # Find chat header record to locate the chat block chain header.
    	my $header = $col->find_one({pair => join(",",sort($gs->{pid}, $gr->{header_id}))});
		
		# update mailbox status
        my $mailbox = obj_read("mailbox", $gs->{pid}, 2);
        
        if ($mailbox->{messages}->{$gr->{header_id}}) {
            # Update the message center visit status. reset new message count to 0.
            $mailbox->{messages}->{$gr->{header_id}}->{vt} = time;
            $mailbox->{messages}->{$gr->{header_id}}->{count} = 0;
            obj_write($mailbox);
        }
        
        # No chat message entry found. Block is null.
        return jr({block => {
            _id => 0,
            type => "messages_block",
            next_id => 0,
            entries => [],
            et => time,
            ut => time,        
        }}) unless $header->{block_id};

        my $block_record = obj_read("messages_block", $header->{block_id});
        
        return jr({ block => $block_record });

    } else {
    
        # No chat message entry found. Block is null.
        return jr({block => {
            _id => 0,
            type => "messages_block",
            next_id => 0,
            entries => [],
            et => time,
            ut => time,        
        }}) unless $gr->{block_id};
        
        my $block_record = obj_read("messages_block", $gr->{block_id});
        
        return jr({ block => $block_record });
    }
}

$p_message_group_get =<<EOF;
retrieve group messages, get a list of group message content entries

INPUT:
    header_id: // group id, get the first block
    block_id: // OR: to request next block of chat entries, use the block id from the last block record

OUTPUT:
    block: {
        _id: "o14489513231757400035", 
        next_id: 0,
        
        entries: [
        
        {
            content:    "Hello?",                    // message content
            from_name:  "Tom",                       // sender name
            from_avatar:"f14477630553830869196",     // sender avatar
            send_time:  1448955461,                  // send timestamp
            sender_pid: "o14477397324317851066",     // sender pid
            mtype:      "text"                       // message type: text/image/voice/link/file
        },
        
        {
            content:    "Hi, whats up", 
            from_name:  "Smith",
            from_avatar:"f14477630553830869190", 
            send_time:  1448955486, 
            sender_pid: "o14477630553830869197", 
            mtype:      "text"
        },
        
        {
            content:    "Jane", 
            from_avatar: "f14477630553830869192", 
            send_time:  1448956085, 
            sender_pid: "o14477397324317851066", 
            mtype:      "text"
        }
        
        ],
        
        type: "messages_block"
    }
    
EOF

sub p_message_group_get {

    # $gs stores the data for this login session. It contains pid of the api caller.
    return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
    if($gr->{header_id}){
    		
        # Find chat header record to locate the chat block chain header.
    	my $header = obj_read("group", $gr->{header_id});
		
		# update mailbox status
        my $mailbox = obj_read("mailbox", $gs->{pid}, 2);
        
        if ($mailbox->{messages}->{$gr->{header_id}}) {
            # Update the message center visit status. reset new message count to 0.
            $mailbox->{messages}->{$gr->{header_id}}->{vt} = time;
            $mailbox->{messages}->{$gr->{header_id}}->{count} = 0;
            obj_write($mailbox);
        }
        
        # No chat message entry found. Block is null.
        return jr({block => {
            _id => 0,
            type => "messages_block",
            next_id => 0,
            entries => [],
            et => time,
            ut => time,        
        }}) unless $header->{block_id};

        my $block_record = obj_read("messages_block", $header->{block_id});
        
        return jr({ block => $block_record });

    } else {
    
        # No chat message entry found. Block is null.
        return jr({block => {
            _id => 0,
            type => "messages_block",
            next_id => 0,
            entries => [],
            et => time,
            ut => time,        
        }}) unless $gr->{block_id};
        
        my $block_record = obj_read("messages_block", $gr->{block_id});
        
        return jr({ block => $block_record });
    }
}

##############################################

$p_message_mailbox = <<EOF;
retrieve list of received and outgoing messages on user message center

INPUT:
    ut: // client cache the returned list, timestamp of lass call

OUTPUT:
    changed: 0/1     // check against input valur ut, and set 1 if any new messages
    ut: unix time    // last update timestamp
    
    mailbox: [
    
    {
        htype:       "group" // conversation header type
        hid:          "o14613657119255800247", 
        ut:          1462579955, 
        vt:          1462579955, 
        count:       0, 
        block:       0, 
		
        title:       "Class 2000 Reunion Group", 
        avatar_fid:  "f14605622061056489944001", 

        last_avatar: "f14605622061056489944001", 
        last_content:"Hello everyone!", 
        last_name:   "John", 
    },
    
    {
        htype:       "chat" // conversation header type
        hid:          "o14589256603505270481", 
        ut:          1462583109, 
        vt:          1462583111, 
        count:       0, 
        block:       "o14625831090064589977", 
		
        title:       "Smith", 
        avatar_fid:  "f14605622061056489944001", 

        last_avatar: "f14605622061056489944001", 
        last_content:"Message Two", 
        last_name:   "Smith", 
    }
    
    ]
EOF

sub p_message_mailbox {

    # $gs stores the data for this log in session. It contains pid of the api caller.
    return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
    
    my @messages = (); 
    
    my $mailbox = obj_read("mailbox", $gs->{pid}, 2);
    
    # No new message.
    return jr({ changed => 0 }) if $gr->{ut} && $gr->{ut} >= $mailbox->{ut};
    
    my @ids = keys %{$mailbox->{messages}};
    
    # Sort the messages, newer first.
    @ids = sort { $mailbox->{messages}->{$b}->{ut} <=> $mailbox->{messages}->{$a}->{ut} } @ids;
    
    foreach my $id (@ids) {
        push @messages, $mailbox->{messages}->{$id}; 
    }
    
    return jr({ changed => 1, ut => $mailbox->{ut}, mailbox => \@messages });
}

sub add_new_message_entry{

    my ($header, $from_id, $mtype, $content) = @_;
    
    return unless assert($header, "", "ERR_HEADER", "Invalid header data structure.");
	
    my $pref = obj_read("person", $from_id);
	
    # Message entry in a chat block.
    my $message = {
        from_id      => $from_id,
        from_avatar  => $pref->{avatar_fid},
        from_name    => $pref->{name},
        mtype        => $mtype, 
        content      => $content, 
        send_time    => time(),
    };
	
    $message->{from_avatar} = $DEFAULT_IMAGE_FID unless $message->{from_avatar};
    $message->{from_name} = "Noname" unless $message->{from_name};
		
    # This is the first message. New block will be created
    if (!$header->{block_id}) {

        my $block;
        
        $block->{_id}     = obj_id();
        $block->{type}    = "messages_block";
        $block->{next_id} = 0;
        $block->{entries} = [];
        
        push @{$block->{entries}}, $message;

        obj_write($block);

        $header->{block_id} = $block->{_id}; 
        
        obj_write($header);
        
    } else {

        my $messages_block = obj_read("messages_block", $header->{block_id});
        
        # Maximum number of chat entries in a block is 50.
        # This is the first message of a new block. New block will be created
        if ((scalar(@{$messages_block->{entries}})+1) > 50) {

            my $block;
            
            $block->{_id}     = obj_id();
            $block->{type}    = "messages_block";
            $block->{next_id} = $messages_block->{_id};
            $block->{entries} = [];
            
            push @{$block->{entries}}, $message;

            obj_write($block); 

            $header->{block_id} = $block->{_id};
            
            obj_write($header);
            
        } else {

            push @{$messages_block->{entries}}, $message;

            obj_write($messages_block); 
        }  
    }
    
    return 1;
}

################################################################################
#                                                                              #
#                  TEST API, TEST VARIOUS SYSTEM CAPABILITIES                  #
#                                                                              #
################################################################################
$p_test_geo = <<EOF;
MongoDB geo location LBS algorithm test

    geotest table needs the following index record

    https://docs.mongodb.com/manual/reference/operator/aggregation/geoNear/
    http://search.cpan.org/~mongodb/MongoDB-v1.4.5/lib/MongoDB/Collection.pm
    
      my \$mocl = mdb()->get_collection("geotest");
      \$mocl->ensure_index({loc=>"2dsphere"});
    
    add two records to geotest collection for testing:

    {
        "_id": "o14732897828623270988",
        "loc": {
            "type": "Point",
            "coordinates": [
                -73.97,
                40.77
            ]
        },
        "name": "Central Park",
        "category": "Parks"
    }

    {
        "_id": "o14732897834963579177",
        "loc": {
            "type": "Point",
            "coordinates": [
                -73.88,
                40.78
            ]
        },
        "name": "La Guardia Airport",
        "category": "Airport"
    }
    
    To test, send request:

        {"obj":"geo","act":"test","dist":0.001}

INPUT:
    dist: rad, 0.01 , 0.001

EOF

sub p_test_geo {

    # aggregate return: result set, not the same as cursor 
    my $result = mdb()->get_collection("geotest")->aggregate([{'$geoNear' => {
        'near'=> [ -73.97 , 40.77 ],
        'spherical'=>1,

        # degree in rad: 0.01 , 0.001
        'maxDistance'=>$gr->{dist},

        # mandatary field, distance
        'distanceField'=>"output_distance",
        }}]);

    my @rt;

    while (my $n = $result->next) {
        push @rt, $n;
    }

    return jr({ r => \@rt });
}

$p_test_apns = <<EOF;
test Apple push notification

Xcode simulator app will connect to APNS development server
and the reported token is not valid for APNS production service.

INPUT:
    phone: device login name

EOF

sub p_test_apns {
    
    return jr() unless assert($gr->{phone}, "phone missing", "ERR_PHONE", "Who to send to?");

    my $account =mdb()->get_collection("account")->find_one({login_name => $gr->{phone}});

    return jr() unless assert($account, "account missing", "ERR_ACCOUNT", "No account found for that phone.");
    my $p = obj_read("person", $account->{pids}->{default});

    my @apns_tokens = ($p->{apns_device_token});
    return jr() unless assert(scalar(@apns_tokens), "deice id missing", "ERR_DEVICE_ID", "Tokens list not found.");

    net_apns_batch({alert=>"apns_test, ".time(), cmd=>"apns_test"}, @apns_tokens);

    return jr({msg => "push notification sent"});
}

$p_test_apnsfb = <<EOF;
Apple push notification feedback service

EOF

sub p_test_apnsfb {
	return jr(net_apnsfb_pruning());
}

sub net_apnsfb_pruning {

=h
  [
    {
      'time_t' => 1259577923,
      'token' => '04ef31c86205...624f390ea878416'
    },
    {
      'time_t' => 1259577926,
      'token' => '04ef31c86205...624f390ea878416'
    },
  ]
=cut

	my $tokens = net_apnsfb();

	my @phons = ();

	foreach my $t (@{$tokens}) {
		my @ps =mdb()->get_collection("person")->find({apns_device_token=>$t->{token}})->all();
			foreach my $p (@ps) {
				my $pref = obj_read("person", $p->{_id});
				next if ($pref->{apns_device_token_ut} > $t->{time_t});
				delete $pref->{apns_device_token};
				delete $pref->{apns_device_token_ut};
				obj_write($pref);
				push @phons, $pref->{phoneNo};
			}
	}

	return {
		pruned_tokens =>$tokens, 
		pruned_tokens_count=>scalar(@{$tokens}), 
		pruned_phones => \@phons, 
		pruned_phones_count => scalar(@phons),
	};
}

sub net_apnsfb {

    my $apns;

    if (__PACKAGE__ =~ /_GA$/) {
    
        $apns = Net::APNS::Feedback->new({
            sandbox => 0,
            cert    => "/var/www/games/app/demo_ga/aps.pem",
            key     => "/var/www/games/app/demo_ga/aps.pem",
            passwd  => "123"
        });
	
    } else {
    
        $apns = Net::APNS::Feedback->new({
            sandbox => 1,
            cert => "/var/www/games/app/demo/pushck.pem",
            key => "/var/www/games/app/demo/PushChatkey.pem",
            passwd  => "123"
        });
    
    }

	return $apns->retrieve_feedback;
}

sub net_apns_batch {
    # json, token1, token2 ...
    # Net::APNS::Persistent - Send Apple APNS notifications over a persistent connection
        
    my $json = shift;
    return unless scalar(@_);

    # disabled for now
    return unless $json->{cmd} eq "apns_test";
    
    my $message = $json->{alert};
    return unless $message;
    $message = encode( "utf8", $message );
    
    my $apns;
    
    if (__PACKAGE__ =~ /_GA$/) {
    
        $apns = Net::APNS::Persistent->new({
            sandbox => 0,
            cert    => "/var/www/games/app/demo_ga/aps.pem",
            key     => "/var/www/games/app/demo_ga/aps.pem",
            passwd  => "123"
        });
    
    } else {
    
        $apns = Net::APNS::Persistent->new({
            sandbox => 1,
             cert => "/var/www/games/app/demo/pushck.pem",
             key => "/var/www/games/app/demo/PushChatkey.pem",
             passwd => "121121121"
        });
    
    }

    my @tokens = @_;
    
    while (my $devicetoken = shift @tokens) {

        $apns->queue_notification(
            $devicetoken,
            
            {
                aps => {
                    alert => $message,
                    sound => 'default',
                    # red dot, count, not used yet
                    badge => 0,
                },
    
                # payload, t - payload type, i - item id
    
                # t - to - topic comment, topic id
                # t - p  - personal chat, person id of the other party
    
                p => $json->{p},
            });
    }

    $apns->send_queue;
    
    $apns->disconnect;
}

################################################################################
#                                                                              #
#   FRAMEWORK HOOKS, CALLBACKS, DB CONFIGURATION, AND SYSTEM CONFIGURATIONS    #
#                                                                              #
################################################################################
sub hook_pid_online {
    # Called when user login.

    my ($server, $pid) = @_;
    syslog("online: $server, $pid");
}

sub hook_pid_offline {
    # Called when user log off.

    my ($server, $pid) = @_;
    
    return if $pid eq $gs->{pid};
    
    syslog("offline: $server, $pid");
}

sub hook_nperl_cron_jobs {
    # Called every minute

    #syslog("cron jobs: ".time);
}

sub hook_hitslog {
    # Hook to collect statistic data
    # Called for every api call

    my $stat = obj_read("system", "daily_stat");
    
    # Collect iterested stat, and return user defined label.
    if ($gr->{obj} eq "person" && $gr->{act} eq "chat") {
        return { person_chat => 1 };
    }
    return { person_chat => 0 };
}

sub hook_hitslog_0359 {
    # Data collected at end of each statistic day 03:59AM
    # Called daily at 03:59AM for daily stat computing

    my $at = $_[0];
    
    # obj_id of type "system" can be of any string
    my $stat = obj_read("system", "daily_stat");
    
    # Still the same minute ?
    return if ($stat->{at} == $at);
    
    $stat->{at} = $at;
    my $data = $stat->{data};
    $stat->{data} = undef;
    $stat->{temp} = undef;
    obj_write($stat);
    
    return $data;
}

sub hook_security_check_failed {
    # Hook to checking permission for action, return false if OK.
    # Called for every api.

    my $interf = $gr->{obj}.":".$gr->{act};
    
    my $pref;  $pref = obj_read("person", $gs->{pid}) if $gs->{pid};
    
    return 0;
}

sub account_server_create_pid {
    # Hook to return a reference of the new obj.
    
    my ($aref, $server) = @_;
    
    # Create skeleton person obj when an account is created.
    my $pref = {
        type => "person",
        _id => obj_id(), 
        account_id => $aref->{_id},
        server => $server,
        display_name => $aref->{display_name},
        et => time,
        ut => time,
    };
        
    obj_write($pref);
    
    return $pref;
}

sub account_server_read_pid {
    # Hook to return a person object.
    
    return obj_read("person", $_[0]);
}

sub mongodb_init {
    # Create MongoDB DB index on collection field.
    
    my $mcol = mdb()->get_collection("account");
    $mcol->ensure_index({login_name=>1, device_id=>1}) if $mcol;
        
    my $mcol = mdb()->get_collection("updatelog");
    $mcol->ensure_index({oid=>1}) if $mcol;
        
    my $mcol = mdb()->get_collection("geotest");
    $mcol->ensure_index({loc=>"2dsphere"}) if $mcol;
}

sub command_line {
    # When this script is used in the context of command line.
    
    my @argv = @_;
    
    my $cmd = shift @argv;
    
    if ($cmd eq "cron4am") {
        return;
    }
    
    print "\n\t$PROJ\@$MODE: cmd=$cmd, command line interface ..\n\n";
    
    if (-f $cmd) {
        # print the error message from die "xxx" within the cmd script 
        do $cmd;  print $@;  return;
    }
    
    if ($cmd eq "test") {
        print "testing cmd line interface ..\n";
        return;
    }
}

# Globals shall be enclosed in this block, which will be run in the context of framework.
sub load_configuration {
    # Do not change these placeholders.
    $APPSTAMP = "TIMEAPPSTAMP";
    $APPREVISION = "CODEREVISION";
    $MONGODB_SERVER = "MONGODBSERVER";
    $MONGODB_USER = "MONGODBUSER";
    $MONGODB_PASSWD = "MONGODBPASSWD";

    %VALID_TYPES = map {$_=>1} (keys %VALID_TYPES, qw(business person test));
    
    $CACHE_ONLY_CACHE_MAX->{sess}     = 2000;
    $READ_CACHE_MAX         = 2000;
    
    $LOCAL_TIMEZONE_GM_SECS = 8*3600;

    # Set these to 0 (default) for performance.
    $SESS_PERSIST = 1;
    $UTF8_SUPPORT = 1;
    
    $DISABLE_SESSLOG = 1;
    $DISABLE_SYSLOG = 0;
    $DISABLE_ERRLOG = 0;
    $ASSOCIATE_UNLOCKED = 1;
    
    # Universal password for testing and development.
    # Comment this line for production server.
    $UNIVERSAL_PASSWD = bytecode_bypass_passwd_encrypt("1");

    # Turn on obj update log. warning: it could slow things down a lot!
    # Only turn it on for development server.
    $UPDATELOG_ENABLED = 1 unless lc(__PACKAGE__) =~ /_ga$/;

    # Stress test will not ping.
    $CLIENT_PING_REQUIRED = 0;
    
    $SECURITY_CHECK_ENABLED = 1;
    
    $MAESTRO_MODE_ENABLED = 0;
    
    # Turn this off for production server
    #$DISABLE_HASH_EMPTY_KEY_CHECK_ON_WRITE = 1;
    
    # Turn this on for production server
    #$PRODUCTION_MODE = 0;
}

sub p_books_entry{
	return jr() unless assert($gr->{name},"name 参数少了","name","name 参数少了");
	return jr() unless assert($gr->{chapterNumber},"chapterNumber 参数少了","chapterNumber","chapterNumber 参数少了");
	return jr() unless assert($gr->{grade},"grade 参数少了","grade","grade 参数少了");
	#return jr() unless assert($gr->{category},"category 参数少了","category","category 参数少了");
	return jr() unless assert($gr->{otherInformation},"otherInformation 参数少了","otherInformation","otherInformation 参数少了");
	return jr() unless assert($gr->{chapterList},"chapterList 参数少了","chapterList","chapterList 参数少了");
	return jr() unless assert($gr->{guidePrice},"guidePrice 参数少了","guidePrice","guidePrice 参数少了");
	return jr() unless assert($gr->{basePrice},"basePrice 参数少了","basePrice","basePrice 参数少了");
	return jr() unless assert($gr->{introduction},"introduction 参数少了","introduction","introduction 参数少了");
	return jr() unless assert($gr->{details},"details 参数少了","details","details 参数少了");

	my $category = "导读版";
	if($gr->{guidePrice} == 0){
		$category = "基础版";
	}
	
	my $books = {
		_id => obj_id(),
		type => 'books',
		name => $gr->{name},
		bookFid => $gr->{bookFid},
		guidePrice => $gr->{guidePrice},
		basePrice => $gr->{basePrice},
		uploadTime => time(),
		chapterNumber => $gr->{chapterNumber},
		grade => $gr->{grade},
		#category => $gr->{category},
		category => $category,
		introduction => $gr->{introduction},
		details => $gr->{details},
		otherInformation => $gr->{otherInformation},
		recommend => $gr->{recommend},
		#pageSpacing => $gr->{pageSpacing},
	};
	
	foreach $item (@{$gr->{chapterList}}){
		my $chapter = {
			_id => obj_id(),
			type => 'chapter',
			name => $gr->{name},
			booksId => $books->{_id},
			chapter => $item->{chapter},
			chapterNum => $item->{chapterNum},
			chapterName => $item->{chapterName},
			chapterPage => $item->{chapterPage},
			pageSpacing => $item->{pageSpacing},
			piece => $item->{piece},
			guideReadingText => $item->{guideReadingText},
			guideReadingAudio => $item->{guideReadingAudio},
			modelReadingText => $item->{modelReadingText},
			modelReadingAudio => $item->{modelReadingAudio},
			evaluationQuestion => $item->{evaluationQuestion},
		};
		
		#从全文中截取第一段
		#my $index = index($chapter->{piece}->{fullText}, "\n");
		#$chapter->{piece}->{firstParagraphOfText} = substr($chapter->{piece}->{fullText},0,$index);
		
		#foreach $pieceItem (@{$item->{piece}}){
		#	my $piece = {
		#		page => $pieceItem->{page},
		#		firstParagraphOfText => $pieceItem->{firstParagraphOfText},
		#		fullText => $pieceItem->{fullText},
		#		uploadResources => $pieceItem->{uploadResources},
		#	};
		#	
		#	push @{$chapter->{piece}}, $piece;
		#}

		foreach $testQuestionsItem (@{$item->{testQuestionsList}}){
			my $testQuestions = {
				_id => obj_id(),
				type => 'testQuestions',
				chapterID => $chapter->{_id},
				pageSpacing => $testQuestionsItem->{pageSpacing},
				stem => $testQuestionsItem->{stem},
				option => $testQuestionsItem->{option},
				multipleChoiceAnswer => $testQuestionsItem->{multipleChoiceAnswer},
				fillInTheBlanksAnswer => $testQuestionsItem->{fillInTheBlanksAnswer},
				fillInTheBlanksTimeLimit => $testQuestionsItem->{fillInTheBlanksTimeLimit},
				multipleChoiceTimeLimit => $testQuestionsItem->{multipleChoiceTimeLimit},
			};
	
			obj_write($testQuestions);
		};
		
		obj_write($chapter);
		#push @{$books->{chapterID}}, $chapter->{_id};
		$books->{ChapterID}->{$item->{chapter}} = $chapter->{_id};
	}

	obj_write($books);

	return jr();
}

$p_books_entry =<<EOF;
上架资源

输入：
	{
		"obj":"books",
		"act":"entry",
		"name":"宝葫芦的秘密",
		"bookFid":"",
		"guidePrice":100,
		"basePrice":100,
		"chapterNumber":10,					章节数
		"grade":"二年级",
		"category":"基础版",
		"introduction":"简介",
		"details":"详情",
		"otherInformation":"",				其他信息(不知道是啥)
		"chapterList":[
			{
				"chapter":"第一章",
				"chapterNum":1,								第几章
				"chapterName":"宝葫芦的秘密",				章节标题
				"chapterPage":"36~98",						页码区间
				"piece":[					本章节的全部部分,分页为一个部分
					{
						"page":1,
						"firstParagraphOfText":"文本第一段(临时演示用)",
						"fullText":"全文",
						"uploadResources":"上传资源(上传语音包或者文字包)",
						"timeLimit":60
					}
				],
				"testQuestionsList":[					测试题
					{
						"pageSpacing":"1~3",
						"stem":"题干",				题干
						"option":{					选项
							"A":"xxx",
							"B":"xxx",
							"C":"xxx",
							"D":"xxx"
						},
						"multipleChoiceAnswer":"A",		选择题答案
						"fillInTheBlanksAnswer":[		填空题答案
							"2",
							"4"
						],
						"fillInTheBlanksTimeLimit":120,				填空题时限(单位:秒)
						"multipleChoiceTimeLimit":120				选择题时限(单位:秒)
					}
				],
				"guideReadingText":"小朋友们好！\n\n现在,老师为你们导读的是中国著名儿童文学作家张天翼爷爷创作的《宝葫芦的秘密》。",
				"guideReadingAudio":"f15377017632681200504001",
				
				"modelReadingText":"我要讲的,正是我自已的一件事情,是我和宝葫芦的故事。\n\n你们也许要问:\n\n“什么？宝芦？就是传说故事星的那种宝葫芦么？”",
				"modelReadingAudio":"f15377017845254731178001",
				
				"evaluationQuestion":{
					"stem":"王葆为了什么事情和苏鸣凤闹了矛盾？",
						"option":{
							"A":"钓鱼",
							"B":"下象棋",
							"C":"做电磁起重机",
							"D":"讲宝葫芦的故事"
						},
					"Answer":"C",
					"problemAnalysis":"我是第一章评测解析,我是第一章评测解析,我是第一章评测解析"
				}
			}
		],
		
	}
EOF

sub p_books_add{
	return jr() unless assert($gr->{booksCode},"booksCode 参数少了","booksCode","booksCode 参数少了");
	
	return jr() unless assert($gr->{name},"name 参数少了","name","name 参数少了");
	return jr() unless assert($gr->{grade},"grade 参数少了","grade","grade 参数少了");
	return jr() unless assert($gr->{bookFid},"bookFid 参数少了","bookFid","bookFid 参数少了");
	return jr() unless assert($gr->{introduction},"introduction 参数少了","introduction","introduction 参数少了");
	return jr() unless assert($gr->{teacherName},"teacherName 参数少了","teacherName","teacherName 参数少了");
	return jr() unless assert($gr->{teacherIntroduction},"teacherIntroduction 参数少了","teacherIntroduction","teacherIntroduction 参数少了");
	return jr() unless assert($gr->{guidePlanFid},"guidePlanFid 参数少了","guidePlanFid","guidePlanFid 参数少了");
	return jr() unless assert($gr->{guidePrice},"guidePrice 参数少了","guidePrice","guidePrice 参数少了");
	return jr() unless assert($gr->{basePrice},"basePrice 参数少了","basePrice","basePrice 参数少了");
	return jr() unless assert($gr->{details},"details 参数少了","details","details 参数少了");
	return jr() unless assert($gr->{recommend},"recommend 参数少了","recommend","recommend 参数少了");
	return jr() unless assert($gr->{status},"status 参数少了","status","status 参数少了");

	my $category = "导读版";
	if($gr->{guidePrice} == 0){
		$category = "基础版";
	}
	
	my $booksTmp = mdb()->get_collection("books")->find_one({name=>$gr->{name}});
	if($booksTmp){
		return jr() unless assert(0,"已有同名课本","已有同名课本","已有同名课本");
	}
	
	my $currentTime = time();
	my $books = {
		_id => obj_id(),
		type => 'books',
		booksCode => $gr->{booksCode},
		name => $gr->{name},
		grade => $gr->{grade},
		bookFid => $gr->{bookFid},
		introduction => $gr->{introduction},
		teacherName => $gr->{teacherName},
		teacherIntroduction => $gr->{teacherIntroduction},
		guidePlanFid => $gr->{guidePlanFid},
		guidePrice => $gr->{guidePrice},
		basePrice => $gr->{basePrice},
		createTime => $currentTime,
		updateTime => $currentTime,
		category => $category,
		details => $gr->{details},
		recommend => $gr->{recommend},
		status => $gr->{status},
	};

	obj_write($books);

	return jr();
}

$p_books_add =<<EOF;
添加课本

输入：
	{
		"obj":"books",
		"act":"add",
		"booksCode"
		"name":"宝葫芦的秘密",
		"grade":"二年级",
		"bookFid":"",
		"introduction":"简介",
		"teacherName":"",
		"teacherIntroduction":"",
		"guidePlanFid":"",
		"guidePrice":100,
		"basePrice":100,
		"details":"详情",
		"recommend":"",		是/否
		"status":"",		上架/下架
	}
EOF

sub p_books_delete{
	return jr() unless assert($gr->{booksId},"booksId 参数少了","booksId","booksId 参数少了");
	
	my $books = mdb()->get_collection("books")->find_one({_id=>$gr->{booksId}});
	if(!$books){
		return jr() unless assert(0,"资源不存在","资源不存在","资源不存在");
	}
	
	if($books->{status} eq "上架"){
		return jr() unless assert(0,"上架资源不允许删除","上架资源不允许删除","上架资源不允许删除");
	}

	my @chapterList = values %{$books->{ChapterID}};
	foreach my $chapterItem(@chapterList){
		my @testQuestionsList = mdb()->get_collection("testQuestions")->find({chapterID=>$chapterItem})->all();
		foreach my $item(@testQuestionsList){
			obj_delete("testQuestions", $item->{_id});
		}
		obj_delete("chapter", $chapterItem);
	}
	
	obj_delete("books", $books->{_id});
	return jr();
}

$p_books_delete =<<EOF;
删除课本

输入：
	{
		"obj":"books",
		"act":"delete",
		"booksId":""
	}
EOF

sub p_books_modify{
	return jr() unless assert($gr->{booksId},"booksId 参数少了","booksId","booksId 参数少了");
	
	my $books = mdb()->get_collection("books")->find_one({_id=>$gr->{booksId}});
	if(!$books){
		return jr() unless assert(0,"资源不存在","资源不存在","资源不存在");
	}
	
	if(length($gr->{booksCode})){
		$books->{booksCode} = $gr->{booksCode};
	}
	
	if(length($gr->{name})){
		$books->{name} = $gr->{name};
		
		my @classAnnouncementList = mdb()->get_collection("classAnnouncement")->find({booksId=>$books->{_id}})->all();
		foreach my $item(@classAnnouncementList){
			$item->{bookName} = $gr->{name};
			obj_write($item);
		}
		
		my @favouriteList = mdb()->get_collection("favourite")->find({booksId=>$books->{_id}})->all();
		foreach my $item(@favouriteList){
			$item->{bookName} = $gr->{name};
			obj_write($item);
		}
		
		my @homeworkShareList = mdb()->get_collection("homeworkShare")->find({booksId=>$books->{_id}})->all();
		foreach my $item(@homeworkShareList){
			$item->{bookName} = $gr->{name};
			obj_write($item);
		}
		
		my @booksHomeworkInfoList = mdb()->get_collection("booksHomeworkInfo")->find({booksId=>$books->{_id}})->all();
		foreach my $item(@booksHomeworkInfoList){
			$item->{bookName} = $gr->{name};
			obj_write($item);
		}
		
		my @homeworkList = mdb()->get_collection("homework")->find({booksId=>$books->{_id}})->all();
		foreach my $item(@homeworkList){
			$item->{bookName} = $gr->{name};
			obj_write($item);
		}
		
		my @readingInfoList = mdb()->get_collection("readingInfo")->find({booksId=>$books->{_id}})->all();
		foreach my $item(@readingInfoList){
			$item->{bookName} = $gr->{name};
			obj_write($item);
		}
		
		my @chapterScheduleList = mdb()->get_collection("chapterSchedule")->find({booksId=>$books->{_id}})->all();
		foreach my $item(@chapterScheduleList){
			$item->{bookName} = $gr->{name};
			obj_write($item);
		}
	}
	
	if(length($gr->{grade})){
		$books->{grade} = $gr->{grade};
	}
	
	if(length($gr->{bookFid})){
		$books->{bookFid} = $gr->{bookFid};
	}
	
	if(length($gr->{introduction})){
		$books->{introduction} = $gr->{introduction};
	}
	if(length($gr->{teacherName})){
		$books->{teacherName} = $gr->{teacherName};
	}
	if(length($gr->{teacherIntroduction})){
		$books->{teacherIntroduction} = $gr->{teacherIntroduction};
	}
	if(length($gr->{guidePlanFid})){
		$books->{guidePlanFid} = $gr->{guidePlanFid};
	}
	if(length($gr->{guidePrice})){
		$books->{guidePrice} = $gr->{guidePrice};
		my $category = "导读版";
		if($gr->{guidePrice} <= 0){
			$category = "基础版";
		}
		$books->{category} = $category;
	}
	if(length($gr->{basePrice})){
		$books->{basePrice} = $gr->{basePrice};
	}
	if(length($gr->{details})){
		$books->{details} = $gr->{details};
	}
	if(length($gr->{recommend})){
		$books->{recommend} = $gr->{recommend};
	}
	if(length($gr->{status})){
		$books->{status} = $gr->{status};
	}

	$books->{updateTime} = time();
	obj_write($books);
	return jr();
}

$p_books_modify =<<EOF;
修改课本

输入：
	{
		"obj":"books",
		"act":"modify",
		"booksId":"",
		"booksCode":"",
		"name":"宝葫芦的秘密",
		"grade":"二年级",
		"bookFid":"",
		"introduction":"简介",
		"teacherName":"",
		"teacherIntroduction":"",
		"guidePlanFid":"",
		"guidePrice":100,
		"basePrice":100,
		"details":"详情",
		"recommend":"",		是/否
		"status":"",		上架/下架
	}
EOF

sub p_books_get{

	my $limit = $gr->{limit};
	$limit = 10 unless $limit;
	
	my $page = $gr->{page};
	$page = 1 unless $page;
	my $skipCount = ($page - 1) * $limit;
	
	#sort 以index字段排序,1为升序,-1为降序
	#limit 读取的记录条数
	#skip 跳过的记录条数
	
	my %regex = ('$regex'=>"regex");
	my %data = ();
	my @conditionalKeys = keys %{$gr->{data}};
	foreach my $item (@conditionalKeys){
		if(!$gr->{data}->{$item}){
			next;
		}
		
		if($item eq "name"){
			$regex{'$regex'} = $gr->{data}->{$item};
			$data{$item} = \%regex;
		}
		#else{
		#	$data{$item} = $gr->{data}->{$item};
		#}
	}

	my @booksList = mdb()->get_collection("books")->find(\%data)->sort({"createTime"=>-1})->limit($limit)->skip($skipCount)->all();
	
	my @booksAllList = mdb()->get_collection("books")->find()->all();
	my $total = @booksAllList;

	return jr({total => $total, booksList=>\@booksList});
}

$p_books_get =<<EOF;
后台管理获取课本

输入：
	{
		"obj":"books",
		"act":"get",
		"data":
		{
			"name":""
		},
		"limit":,
		"page":
	}
输出：
	{
		"total":123,
		"booksList":[]
	}
EOF

sub p_booksStatus_change{
	return jr() unless assert($gr->{booksId},"booksId 参数少了","booksId","booksId 参数少了");
	return jr() unless assert($gr->{status},"status 参数少了","status","status 参数少了");
	
	my $books = mdb()->get_collection("books")->find_one({_id=>$gr->{booksId}});
	if(!$books){
		return jr() unless assert(0,"资源不存在","资源不存在","资源不存在");
	}

	$books->{status} = $gr->{status};
	obj_write($books);
	
	return jr();
}

$p_booksStatus_change =<<EOF;
课本上下架

输入：
	{
		"obj":"booksStatus",
		"act":"change",
		"booksId":"",
		"status":""		上架/下架
	}
EOF

sub p_chapter_add{
	return jr() unless assert($gr->{booksId},"booksId 参数少了","booksId","booksId 参数少了");
	return jr() unless assert($gr->{chapterCode},"chapterCode 参数少了","chapterCode","chapterCode 参数少了");
	return jr() unless assert($gr->{chapterFid},"chapterFid 参数少了","chapterFid","chapterFid 参数少了");
	return jr() unless assert($gr->{startPage},"startPage 参数少了","startPage","startPage 参数少了");
	return jr() unless assert($gr->{endPage},"endPage 参数少了","endPage","endPage 参数少了");
	return jr() unless assert($gr->{guideReadingText},"guideReadingText 参数少了","guideReadingText","guideReadingText 参数少了");
	return jr() unless assert($gr->{guideReadingAudio},"guideReadingAudio 参数少了","guideReadingAudio","guideReadingAudio 参数少了");
	return jr() unless assert($gr->{modelReadingText},"modelReadingText 参数少了","modelReadingText","modelReadingText 参数少了");
	return jr() unless assert($gr->{modelReadingAudio},"modelReadingAudio 参数少了","modelReadingAudio","modelReadingAudio 参数少了");
	return jr() unless assert($gr->{modelReadingStartPage},"modelReadingStartPage 参数少了","modelReadingStartPage","modelReadingStartPage 参数少了");
	return jr() unless assert($gr->{modelReadingEndPage},"modelReadingEndPage 参数少了","modelReadingEndPage","modelReadingEndPage 参数少了");
	return jr() unless assert($gr->{evaluationQuestion},"evaluationQuestion 参数少了","evaluationQuestion","evaluationQuestion 参数少了");
	return jr() unless assert($gr->{piece},"piece 参数少了","piece","piece 参数少了");
	#return jr() unless assert($gr->{chapter},"chapter 参数少了","chapter","chapter 参数少了");
	return jr() unless assert($gr->{chapterNum},"chapterNum 参数少了","chapterNum","chapterNum 参数少了");
	return jr() unless assert($gr->{name},"name 参数少了","name","name 参数少了");
	
	if(!scalar(@{$gr->{piece}})){
		return jr() unless assert(0,"页码内容未填写","页码内容未填写","页码内容未填写");
	}
	
	my $books = mdb()->get_collection("books")->find_one({_id=>$gr->{booksId}});
	if(!$books){
		return jr() unless assert(0,"资源不存在","资源不存在","资源不存在");
	}
	
	my $chapterTmp = mdb()->get_collection("chapter")->find_one({booksId=>$gr->{booksId}, name=>$gr->{name}});
	if($chapterTmp){
		return jr() unless assert(0,"章节名重复","章节名重复","章节名重复");
	}
	
	$chapterTmp = mdb()->get_collection("chapter")->find_one({booksId=>$gr->{booksId}, chapterNum=>$gr->{chapterNum}});
	if($chapterTmp){
		return jr() unless assert(0,"章节序号重复","章节序号重复","章节序号重复");
	}
	
	my $chapterPage = $gr->{startPage}."~".$gr->{endPage};
	my $chapter = {
		_id => obj_id(),
		type => 'chapter',
		chapterCode => $gr->{chapterCode},
		name => $gr->{name},
		chapterFid => $gr->{chapterFid},
		startPage => $gr->{startPage},
		endPage => $gr->{endPage},
		guideReadingText => $gr->{guideReadingText},
		guideReadingAudio => $gr->{guideReadingAudio},
		modelReadingText => $gr->{modelReadingText},
		modelReadingAudio => $gr->{modelReadingAudio},
		modelReadingStartPage => $gr->{modelReadingStartPage},
		modelReadingEndPage => $gr->{modelReadingEndPage},
		evaluationQuestion => $gr->{evaluationQuestion},
		piece => $gr->{piece},
		
		booksId => $books->{_id},
		booksName => $books->{name},
		chapter => "第".$gr->{chapterNum}."章",
		chapterNum => $gr->{chapterNum},
		chapterPage => $chapterPage,
		#pageSpacing => $chapterPageSpacing,
	};

	my @chapterPageSpacing = ();
	foreach $testQuestionsItem (@{$gr->{testQuestionsList}}){
		my $pageSpacing = $testQuestionsItem->{startPage}."~".$testQuestionsItem->{endPage};
		foreach my $item(@{$testQuestionsItem->{question}}){
			my @fillInTheBlanksAnswer = ();
			push @fillInTheBlanksAnswer, $item->{fillInTheBlanksAnswer1};
			push @fillInTheBlanksAnswer, $item->{fillInTheBlanksAnswer2};
			my $testQuestions = {
				_id => obj_id(),
				type => 'testQuestions',
				name => $testQuestionsItem->{name},
				chapterID => $chapter->{_id},
				startPage => $testQuestionsItem->{startPage},
				endPage => $testQuestionsItem->{endPage},
				pageSpacing => $pageSpacing,
				stem => $item->{stem},
				option => $item->{option},
				multipleChoiceAnswer => $item->{multipleChoiceAnswer},
				fillInTheBlanksAnswer => \@fillInTheBlanksAnswer,
				#fillInTheBlanksTimeLimit => $testQuestionsItem->{fillInTheBlanksTimeLimit},
				#multipleChoiceTimeLimit => $testQuestionsItem->{multipleChoiceTimeLimit},
			};
			obj_write($testQuestions);
		}
		push @chapterPageSpacing, $pageSpacing;
	};
	
	$chapter->{pageSpacing} = \@chapterPageSpacing;
	obj_write($chapter);
	$books->{ChapterID}->{$chapter->{chapter}} = $chapter->{_id};

	obj_write($books);

	return jr();
}

$p_chapter_add =<<EOF;
添加章节

输入：
	{
		"obj":"chapter",
		"act":"add",
		"booksId":"",
		"chapterCode":"",
		"name":"宝葫芦的秘密",				章节标题
		"chapterFid":"",
		"startPage":"",
		"endPage":"",
		#"chapter":"第一章",
		"chapterNum":1,								第几章
		"piece":[					本章节的全部部分,分页为一个部分
			{
				"page":1,
				"firstParagraphOfText":"文本第一段",
				"fullText":"全文"
			}
		],
		
		#"testQuestionsList":[					测试题
		#	{
		#		"name":"",
		#		"startPage":
		#		"endPage":
		#		"stem":"题干",				题干
		#		"option":{					选项
		#			"A":"xxx",
		#			"B":"xxx",
		#			"C":"xxx",
		#			"D":"xxx"
		#		},
		#		"multipleChoiceAnswer":"A",		选择题答案
		#		"fillInTheBlanksAnswer":[		填空题答案
		#			"2",
		#			"4"
		#		]
		#	}
		#],
		
		"testQuestionsList":[					测试题
			{
				"name":"",
				"startPage":
				"endPage":
				"question":[
					{
						"stem":"题干",				题干
						"option":{					选项
							"A":"xxx",
							"B":"xxx",
							"C":"xxx",
							"D":"xxx"
						},
						"multipleChoiceAnswer":"A",		选择题答案
						"fillInTheBlanksAnswer1":"",		填空题答案
						"fillInTheBlanksAnswer2":"",		填空题答案
					}
				]
			}
		],
		
		"guideReadingText":"导读文字",
		"guideReadingAudio":"导读音频",
			
		"modelReadingText":"范读文字",
		"modelReadingAudio":"范读音频",
		"modelReadingStartPage":"范读文字范围起始页",
		"modelReadingEndPage":"范读文字范围结束页",
			
		"evaluationQuestion":{
			"stem":"王葆为了什么事情和苏鸣凤闹了矛盾？",
				"option":{
					"A":"钓鱼",
					"B":"下象棋",
					"C":"做电磁起重机",
					"D":"讲宝葫芦的故事"
				},
			"Answer":"C",
			"problemAnalysis":"我是第一章评测解析,我是第一章评测解析,我是第一章评测解析"
		}
	}
EOF

sub p_chapter_delete{
	return jr() unless assert($gr->{chapterId},"chapterId 参数少了","chapterId","chapterId 参数少了");
	
	my $chapter = mdb()->get_collection("chapter")->find_one({_id=>$gr->{chapterId}});
	if(!$chapter){
		return jr() unless assert(0,"资源不存在","资源不存在","资源不存在");
	}
	
	my $books = mdb()->get_collection("books")->find_one({_id=>$chapter->{booksId}});
	if(!$books){
		return jr() unless assert(0,"资源不存在","资源不存在","资源不存在");
	}
	
	delete ${$books->{ChapterID}}{$chapter->{chapter}};
	
	my @testList = mdb()->get_collection("testQuestions")->find({chapterID=>$chapter->{_id}})->all();
	foreach my $item(@testList){
		obj_delete("testQuestions", $item->{_id});
	}
	
	obj_delete("chapter", $chapter->{_id});
	return jr();
}

$p_chapter_delete =<<EOF;
删除章节

输入：
	{
		"obj":"books",
		"act":"entry",
		"chapterId":""
	}
EOF

sub p_chapter_modify{
	return jr() unless assert($gr->{chapterId},"chapterId 参数少了","chapterId","chapterId 参数少了");
	
	my $chapter = mdb()->get_collection("chapter")->find_one({_id=>$gr->{chapterId}});
	if(!$chapter){
		return jr() unless assert(0,"资源不存在","资源不存在","资源不存在");
	}
	
	my $books = mdb()->get_collection("books")->find_one({_id=>$chapter->{booksId}});
	if(!$books){
		return jr() unless assert(0,"资源不存在","资源不存在","资源不存在");
	}
	
	if(length($gr->{chapterCode})){
		$chapter->{chapterCode} = $gr->{chapterCode};
	}
	if(length($gr->{name})){
		$chapter->{name} = $gr->{name};
	}
	if(length($gr->{chapterFid})){
		$chapter->{chapterFid} = $gr->{chapterFid};
	}
	if(length($gr->{startPage})){
		$chapter->{startPage} = $gr->{startPage};
		my $chapterPage = $chapter->{startPage}."~".$chapter->{endPage};
		$chapter->{chapterPage} = $chapterPage;
	}
	if(length($gr->{endPage})){
		$chapter->{endPage} = $gr->{endPage};
		my $chapterPage = $chapter->{startPage}."~".$chapter->{endPage};
		$chapter->{chapterPage} = $chapterPage;
	}
	if(length($gr->{guideReadingText})){
		$chapter->{guideReadingText} = $gr->{guideReadingText};
	}
	if(length($gr->{guideReadingAudio})){
		$chapter->{guideReadingAudio} = $gr->{guideReadingAudio};
	}
	if(length($gr->{modelReadingText})){
		$chapter->{modelReadingText} = $gr->{modelReadingText};
	}
	if(length($gr->{modelReadingAudio})){
		$chapter->{modelReadingAudio} = $gr->{modelReadingAudio};
	}
	#if(length($gr->{modelReadingPage})){
	#	$chapter->{modelReadingPage} = $gr->{modelReadingPage};
	#}
	
	if(length($gr->{modelReadingStartPage})){
		$chapter->{modelReadingStartPage} = $gr->{modelReadingStartPage};
	}
	if(length($gr->{modelReadingEndPage})){
		$chapter->{modelReadingEndPage} = $gr->{modelReadingEndPage};
	}
	if(length($gr->{evaluationQuestion})){
		$chapter->{evaluationQuestion} = $gr->{evaluationQuestion};
	}
	if(length($gr->{piece})){
		$chapter->{piece} = $gr->{piece};
	}
	if(length($gr->{chapter})){
		delete ${$books->{ChapterID}}{$chapter->{chapter}};
		$chapter->{chapter} = $gr->{chapter};
		$books->{ChapterID}->{$chapter->{chapter}} = $chapter->{_id};
		obj_write($books);
	}
	if(length($gr->{chapterNum})){
		delete ${$books->{ChapterID}}{$chapter->{chapter}};
		
		$chapter->{chapterNum} = $gr->{chapterNum};
		$chapter->{chapter} = "第".$gr->{chapterNum}."章";
		
		$books->{ChapterID}->{$chapter->{chapter}} = $chapter->{_id};
		obj_write($books);
	}
	
	
	my @classAnnouncementList = mdb()->get_collection("classAnnouncement")->find({chapterId=>$chapter->{_id}})->all();
	foreach my $item(@classAnnouncementList){
		$item->{chapterName} = $chapter->{name};
		obj_write($item);
	}

	my @homeworkShareList = mdb()->get_collection("homeworkShare")->find({chapterId=>$chapter->{_id}})->all();
	foreach my $item(@homeworkShareList){
		$item->{chapterName} = $chapter->{name};
		$item->{pageSpacing} = $chapter->{chapterPage};
		obj_write($item);
	}

	my @homeworkList = mdb()->get_collection("homework")->find({chapterId=>$chapter->{_id}})->all();
	foreach my $item(@homeworkList){
		$item->{chapterName} = $chapter->{name};
		$item->{chapterNum} = $chapter->{chapterNum};
		$item->{pageSpacing} = $chapter->{chapterPage};
		obj_write($item);
	}
	
	my @readingInfoList = mdb()->get_collection("readingInfo")->find({chapterId=>$chapter->{_id}})->all();
	foreach my $item(@readingInfoList){
		$item->{chapterName} = $chapter->{name};
		$item->{chapterPage} = $chapter->{chapterPage};
		obj_write($item);
	}
	
	my @chapterScheduleList = mdb()->get_collection("chapterSchedule")->find({chapterId=>$chapter->{_id}})->all();
	foreach my $item(@chapterScheduleList){
		$item->{chapterName} = $chapter->{name};
		$item->{chapterPage} = $chapter->{chapterPage};
		$item->{chapterNum} = $chapter->{chapterNum};
		obj_write($item);
	}

	my @testList = mdb()->get_collection("testQuestions")->find({chapterID=>$chapter->{_id}})->all();
	foreach my $item(@testList){
		obj_delete("testQuestions", $item->{_id});
	}
	
	my @chapterPageSpacing = ();
	foreach $testQuestionsItem (@{$gr->{testQuestionsList}}){
		my $pageSpacing = $testQuestionsItem->{startPage}."~".$testQuestionsItem->{endPage};
		foreach my $item(@{$testQuestionsItem->{question}}){
			my @fillInTheBlanksAnswer = ();
			push @fillInTheBlanksAnswer, $item->{fillInTheBlanksAnswer1};
			push @fillInTheBlanksAnswer, $item->{fillInTheBlanksAnswer2};
			my $testQuestions = {
				_id => obj_id(),
				type => 'testQuestions',
				name => $testQuestionsItem->{name},
				chapterID => $chapter->{_id},
				startPage => $testQuestionsItem->{startPage},
				endPage => $testQuestionsItem->{endPage},
				pageSpacing => $pageSpacing,
				stem => $item->{stem},
				option => $item->{option},
				multipleChoiceAnswer => $item->{multipleChoiceAnswer},
				fillInTheBlanksAnswer => \@fillInTheBlanksAnswer,
			};
			obj_write($testQuestions);
		}
		push @chapterPageSpacing, $pageSpacing;
	};
	
	$chapter->{pageSpacing} = \@chapterPageSpacing;
	obj_write($chapter);

	return jr();
}

$p_chapter_modify =<<EOF;
修改章节

输入：
	{
		"obj":"chapter",
		"act":"modify",
		"chapterId":"",
		"chapterCode":"",
		"name":"宝葫芦的秘密",				章节标题
		"chapterFid":"",
		"startPage":"",
		"endPage":"",
		"chapter":"第一章",
		"chapterNum":1,								第几章
		"piece":[					本章节的全部部分,分页为一个部分
			{
				"page":1,
				"firstParagraphOfText":"文本第一段",
				"fullText":"全文"
			}
		],
		
		"testQuestionsList":[					测试题
			{
				"name":"",
				"startPage":
				"endPage":
				"question":[
					{
						"stem":"题干",				题干
						"option":{					选项
							"A":"xxx",
							"B":"xxx",
							"C":"xxx",
							"D":"xxx"
						},
						"multipleChoiceAnswer":"A",		选择题答案
						"fillInTheBlanksAnswer1":"",		填空题答案
						"fillInTheBlanksAnswer2":"",		填空题答案
					}
				]
			}
		],
		#"testQuestionsList":[					测试题
		#	{
		#		"name":"",
		#		"startPage":
		#		"endPage":
		#		"stem":"题干",				题干
		#		"option":{					选项
		#			"A":"xxx",
		#			"B":"xxx",
		#			"C":"xxx",
		#			"D":"xxx"
		#		},
		#		"multipleChoiceAnswer":"A",		选择题答案
		#		"fillInTheBlanksAnswer":[		填空题答案
		#			"2",
		#			"4"
		#		]
		#	}
		#],
		"guideReadingText":"导读文字",
		"guideReadingAudio":"导读音频",
			
		"modelReadingText":"范读文字",
		"modelReadingAudio":"范读音频",
		"modelReadingStartPage":"范读文字范围起始页",
		"modelReadingEndPage":"范读文字范围结束页",
			
		"evaluationQuestion":{
			"stem":"王葆为了什么事情和苏鸣凤闹了矛盾？",
				"option":{
					"A":"钓鱼",
					"B":"下象棋",
					"C":"做电磁起重机",
					"D":"讲宝葫芦的故事"
				},
			"Answer":"C",
			"problemAnalysis":"我是第一章评测解析,我是第一章评测解析,我是第一章评测解析"
		}
	}
EOF

sub p_chapterList_get{
	return jr() unless assert($gr->{booksId},"booksId 参数少了","booksId","booksId 参数少了");
	
	my $books = mdb()->get_collection("books")->find_one({_id=>$gr->{booksId}});
	if(!$books){
		return jr() unless assert(0,"资源不存在","资源不存在","资源不存在");
	}
	
	my @chapterList = mdb()->get_collection("chapter")->find({booksId=>$gr->{booksId}})->all();
	
	foreach my $item (@chapterList){
		my @testQuestionsList = ();
		my @chapterPageSpacing = @{$item->{pageSpacing}};
		foreach my $pageSpacingItem(@chapterPageSpacing){
			my @testQuestions = mdb()->get_collection("testQuestions")->find({chapterID=>$item->{_id}, pageSpacing=>$pageSpacingItem})->all();
			
			my $testQuestionsTmp;
			foreach my $testQuestionsItem(@testQuestions){
				if(!$testQuestionsTmp){
					$testQuestionsTmp->{name} = $testQuestionsItem->{name};
					$testQuestionsTmp->{startPage} = $testQuestionsItem->{startPage};
					$testQuestionsTmp->{endPage} = $testQuestionsItem->{endPage};
				}
				
				my $questionItem = {
					stem => $testQuestionsItem->{stem},
					option => $testQuestionsItem->{option},
					multipleChoiceAnswer => $testQuestionsItem->{multipleChoiceAnswer},
					fillInTheBlanksAnswer1 => ${$testQuestionsItem->{fillInTheBlanksAnswer}}[0],
					fillInTheBlanksAnswer2 => ${$testQuestionsItem->{fillInTheBlanksAnswer}}[1],
				};
				
				push @{$testQuestionsTmp->{question}}, $questionItem;
			}
			
			push @testQuestionsList, $testQuestionsTmp;
		}
		#my @testQuestions = mdb()->get_collection("testQuestions")->find({chapterID=>$item->{_id}})->all();
		$item->{testQuestionsList} = \@testQuestionsList;
	}
	
	my @chapterListTmp = sort {$a->{chapterNum} <=> $b->{chapterNum}} @chapterList;
	
	return jr({chapterList=>\@chapterListTmp});
}

$p_chapterList_get =<<EOF;
查找章节

输入：
	{
		"obj":"chapterList",
		"act":"get",
		"booksId":""
	}
输出：
	{
		"chapterList":[]
	}
EOF

#begin 学生端
sub p_silentReading_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}

	my $currentTime = time();
	my $homework = mdb()->get_collection("homework")->find_one({teacherCode=>$pref->{teacherCode}, startTime =>{'$lt'=>$currentTime}, finishTime =>{'$gt'=>$currentTime}});
	
	if(!$homework){
		return jr() unless assert(0, "暂无课程", "暂无课程", "暂无课程");
	}
	
    #my $books = mdb()->get_collection("chapter")->find_one({name=>$name,chapter=>$chapter});
	my $chapter = mdb()->get_collection("chapter")->find_one({_id=>$homework->{chapterId}});
	if(!$chapter){
		assert(0,"资源不存在","not found","资源不存在");
	}
	
	my $readingInfo = mdb()->get_collection("readingInfo")->find_one({chapterID=>$chapter->{_id}});
	
	my $Schedule = mdb()->get_collection("chapterSchedule")->find_one({studentId=>$gs->{pid},chapterID=>$chapter->{_id}});
	
	my $category = "导读版";
	if($pref->{freeTrial} ne "是"){
		my $order = mdb()->get_collection("order")->find_one({personId=>$gs->{pid}, booksId=>$chapter->{booksId}, Order_Status=>"已完成"});
		if(!$order){
			return jr() unless assert(0,"未购买此图书","未购买此图书","未购买此图书");
		}
		$category = $order->{category};
	}
	
	#if($category eq "导读版"){
	#	if(!$Schedule or $Schedule->{modelReadingState} ne "已完成"){
	#		return jr() unless assert(0,"阅读顺序错误","阅读顺序错误","阅读顺序错误");
	#	}
	#}
	
	if(!$readingInfo){
		$readingInfo->{_id} = obj_id();
		$readingInfo->{type} = "readingInfo";
		$readingInfo->{teacherCode} = $pref->{teacherCode};
		$readingInfo->{booksId} = $chapter->{booksId};
		$readingInfo->{bookName} = $chapter->{name};
		$readingInfo->{chapterPage} = $chapter->{chapterPage};
		$readingInfo->{chapterID} = $chapter->{_id};
		$readingInfo->{chapterName} = $chapter->{name};
		$readingInfo->{startTime} = time();
		$readingInfo->{finishTime} = 0;
		$readingInfo->{readDays} = 0;
		if($readingInfo->{readingState} ne "已完成"){
			$readingInfo->{readingState} = "阅读中";
		}
	}
	obj_write($readingInfo);

	if(!$Schedule){
		$Schedule->{_id} = obj_id();
		$Schedule->{type} = "chapterSchedule";
		$Schedule->{teacherCode} = $pref->{teacherCode};
		$Schedule->{studentId} = $gs->{pid};
		$Schedule->{studentName} = $pref->{name};
		$Schedule->{booksId} = $chapter->{booksId};
		$Schedule->{bookName} = $chapter->{name};
		$Schedule->{chapterID} = $chapter->{_id};
		$Schedule->{chapterName} = $chapter->{name};
		$Schedule->{chapterNum} = $chapter->{chapterNum};
		$Schedule->{chapterPage} = $chapter->{chapterPage};
		$Schedule->{startTime} = time();
		$Schedule->{finishTime} = 0;
		$Schedule->{readDays} = 0;
		if($Schedule->{readingState} ne "已完成"){
			$Schedule->{readingState} = "阅读中";
		}
		$Schedule->{guideReadingState} = "未开始";
		$Schedule->{modelReadingState} = "未开始";
		$Schedule->{readingAloudState} = "未开始";
		$Schedule->{silentReadingState} = "阅读中";
		$Schedule->{testQuestionsState} = "未开始";
	}
	obj_write($Schedule);
	
    return jr({chapter => $chapter});
}

$p_silentReading_get =<<EOF;
获取默读文本

输入：
	{
		"obj":"silentReading",
		"act":"get"
	}
EOF

sub p_testQuestions_get{
	return jr() unless assert($gr->{chapterID},"chapterID 参数少了","chapterID","chapterID 参数少了");
	return jr() unless assert($gr->{pageSpacing},"pageSpacing 参数少了","pageSpacing","pageSpacing 参数少了");
	
	my @testQuestions = mdb()->get_collection("testQuestions")->find({chapterID=>$gr->{chapterID}, pageSpacing=>$gr->{pageSpacing}})->all();

    return jr({testQuestions => \@testQuestions});
}

$p_testQuestions_get =<<EOF;
获取默读测试题

输入：
	{
		"obj":"testQuestions",
		"act":"get",
		"chapterID":"xxxxxx",
		"pageSpacing":"1~3"
	}
EOF

sub p_readingAloud_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");

	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	my $currentTime = time();
	my $homework = mdb()->get_collection("homework")->find_one({teacherCode=>$pref->{teacherCode}, startTime =>{'$lt'=>$currentTime}, finishTime =>{'$gt'=>$currentTime}});
	
	if(!$homework){
		return jr() unless assert(0, "暂无课程", "暂无课程", "暂无课程");
	}
	
	my $chapter = mdb()->get_collection("chapter")->find_one({_id=>$homework->{chapterId}});
	if(!$chapter){
		return jr() unless assert(0,"资源不存在","not found","资源不存在");
	}

	my $readingInfo = mdb()->get_collection("readingInfo")->find_one({chapterID=>$chapter->{_id}});
	
	my $Schedule = mdb()->get_collection("chapterSchedule")->find_one({studentId=>$gs->{pid},chapterID=>$chapter->{_id}});
	
	my $category = "导读版";
	if($pref->{freeTrial} ne "是"){
		my $order = mdb()->get_collection("order")->find_one({personId=>$gs->{pid}, booksId=>$chapter->{booksId}, Order_Status=>"已完成"});
		if(!$order){
			return jr() unless assert(0,"未购买此图书","未购买此图书","未购买此图书");
		}
		$category = $order->{category};
	}
	
	if($category eq "导读版"){
		if(!$Schedule or $Schedule->{modelReadingState} ne "已完成"){
			return jr() unless assert(0,"阅读顺序错误","阅读顺序错误","阅读顺序错误");
		}
	}
	
	if(!$readingInfo){
		$readingInfo->{_id} = obj_id();
		$readingInfo->{type} = "readingInfo";
		$readingInfo->{teacherCode} = $pref->{teacherCode};
		$readingInfo->{booksId} = $chapter->{booksId};
		$readingInfo->{bookName} = $chapter->{name};
		$readingInfo->{chapterPage} = $chapter->{chapterPage};
		$readingInfo->{chapterID} = $chapter->{_id};
		$readingInfo->{chapterName} = $chapter->{name};
		$readingInfo->{startTime} = time();
		$readingInfo->{finishTime} = 0;
		$readingInfo->{readDays} = 0;
		if($readingInfo->{readingState} ne "已完成"){
			$readingInfo->{readingState} = "阅读中";
		}
	}
	obj_write($readingInfo);

	if(!$Schedule){
		$Schedule->{_id} = obj_id();
		$Schedule->{type} = "chapterSchedule";
		$Schedule->{teacherCode} = $pref->{teacherCode};
		$Schedule->{studentId} = $gs->{pid};
		$Schedule->{studentName} = $pref->{name};
		$Schedule->{booksId} = $chapter->{booksId};
		$Schedule->{bookName} = $chapter->{name};
		$Schedule->{chapterID} = $chapter->{_id};
		$Schedule->{chapterName} = $chapter->{name};
		$Schedule->{chapterNum} = $chapter->{chapterNum};
		$Schedule->{chapterPage} = $chapter->{chapterPage};
		$Schedule->{startTime} = time();
		$Schedule->{finishTime} = 0;
		$Schedule->{readDays} = 0;
		if($Schedule->{readingState} ne "已完成"){
			$Schedule->{readingState} = "阅读中";
		}
		$Schedule->{guideReadingState} = "未开始";
		$Schedule->{modelReadingState} = "未开始";
		
		if($Schedule->{readingAloudState} ne "已完成"){
			$Schedule->{readingAloudState} = "阅读中";
		}
		
		$Schedule->{silentReadingState} = "未开始";
		$Schedule->{testQuestionsState} = "未开始";
	}
	obj_write($Schedule);

    return jr({chapter => $chapter});
}

$p_readingAloud_get =<<EOF;
获取朗读文本

输入：
	{
		"obj":"readingAloud",
		"act":"get"
	}
EOF
	
sub p_guideReading_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	#readingInfo_set($gr->{id},$gs->{pid});
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	my $currentTime = time();
	my $homework = mdb()->get_collection("homework")->find_one({teacherCode=>$pref->{teacherCode}, startTime =>{'$lt'=>$currentTime}, finishTime =>{'$gt'=>$currentTime}});
	
	if(!$homework){
		return jr() unless assert(0, "暂无课程", "暂无课程", "暂无课程");
	}

	my $chapter = mdb()->get_collection("chapter")->find_one({_id=>$homework->{chapterId}});
	if(!$chapter){
		return jr() unless assert(0,"资源不存在","not found","资源不存在");
	}
	
	my $category = "导读版";
	if($pref->{freeTrial} ne "是"){
		my $order = mdb()->get_collection("order")->find_one({personId=>$gs->{pid}, booksId=>$homework->{booksId}, Order_Status=>"已完成"});
		if(!$order){
			return jr() unless assert(0,"未购买此图书","未购买此图书","未购买此图书");
		}
		$category = $order->{category};
	}
	
	if($category ne "导读版"){
		return jr() unless assert(0,"导读版才有导读","导读版才有导读","导读版才有导读");
	}
	
	my $readingInfo = mdb()->get_collection("readingInfo")->find_one({chapterID=>$chapter->{_id}});
	if(!$readingInfo){
		$readingInfo->{_id} = obj_id();
		$readingInfo->{teacherCode} = $pref->{teacherCode};
		$readingInfo->{type} = "readingInfo";
		$readingInfo->{booksId} = $chapter->{booksId};
		$readingInfo->{bookName} = $chapter->{name};
		$readingInfo->{chapterPage} = $chapter->{chapterPage};
		$readingInfo->{chapterID} = $chapter->{_id};
		$readingInfo->{chapterName} = $chapter->{name};
		$readingInfo->{startTime} = time();
		$readingInfo->{finishTime} = 0;
		$readingInfo->{readDays} = 0;
		$readingInfo->{readingState} = "阅读中";
	}
	obj_write($readingInfo);
	
	my $Schedule = mdb()->get_collection("chapterSchedule")->find_one({studentId=>$gs->{pid},chapterID=>$chapter->{_id}});
	if(!$Schedule){
		$Schedule->{_id} = obj_id();
		$Schedule->{type} = "chapterSchedule";
		$Schedule->{teacherCode} = $pref->{teacherCode};
		$Schedule->{studentId} = $gs->{pid};
		$Schedule->{studentName} = $pref->{name};
		$Schedule->{booksId} = $chapter->{booksId};
		$Schedule->{bookName} = $chapter->{name};
		$Schedule->{chapterPage} = $chapter->{chapterPage};
		$Schedule->{chapterID} = $chapter->{_id};
		$Schedule->{chapterName} = $chapter->{name};
		$Schedule->{chapterNum} = $chapter->{chapterNum};
		$Schedule->{startTime} = time();
		$Schedule->{finishTime} = 0;
		$Schedule->{readDays} = 0;
		$Schedule->{readingState} = "阅读中";
		$Schedule->{guideReadingState} = "阅读中";
		$Schedule->{modelReadingState} = "未开始";
		$Schedule->{readingAloudState} = "未开始";
		$Schedule->{silentReadingState} = "未开始";
		$Schedule->{testQuestionsState} = "未开始";
	}
	obj_write($Schedule);
	
    return jr({chapter=>$chapter->{chapter}, chapterName=>$chapter->{name}, guideReadingText => $chapter->{guideReadingText}, guideReadingAudio=>$chapter->{guideReadingAudio}});
}

$p_guideReading_get =<<EOF;
获取导读信息

输入：
	{
		"obj":"guideReading",
		"act":"get"
	}
输出:
	{
		"guideReadingText":"",		导读文字
		"guideReadingAudio":"",		导读音频
		"chapterName":"",
		"chapter":""
	}
EOF

sub p_modelReading_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	my $currentTime = time();
	my $homework = mdb()->get_collection("homework")->find_one({teacherCode=>$pref->{teacherCode}, startTime =>{'$lt'=>$currentTime}, finishTime =>{'$gt'=>$currentTime}});
	
	if(!$homework){
		return jr() unless assert(0, "暂无课程", "暂无课程", "暂无课程");
	}
	
	my $chapter = mdb()->get_collection("chapter")->find_one({_id=>$homework->{chapterId}});
	if(!$chapter){
		assert(0,"资源不存在","not found","资源不存在");
	}

	my $category = "导读版";
	if($pref->{freeTrial} ne "是"){
		my $order = mdb()->get_collection("order")->find_one({personId=>$gs->{pid}, booksId=>$chapter->{booksId}, Order_Status=>"已完成"});
		if(!$order){
			return jr() unless assert(0,"未购买此图书","未购买此图书","未购买此图书");
		}
		$category = $order->{category};
	}
	
	if($category ne "导读版"){
		return jr() unless assert(0,"导读版才有范读","导读版才有范读","导读版才有范读");
	}
	
	my $Schedule = mdb()->get_collection("chapterSchedule")->find_one({studentId=>$gs->{pid},chapterID=>$chapter->{_id}});
	if(!$Schedule or $Schedule->{guideReadingState} ne "已完成"){
		return jr() unless assert(0, "阅读顺序错误", "阅读顺序错误", "阅读顺序错误");
	}
	
	if($Schedule->{modelReadingState} ne "已完成"){
		$Schedule->{modelReadingState} = "阅读中";
	}
	obj_write($Schedule);
	
    return jr({chapter=>$chapter->{chapter}, chapterName=>$chapter->{name}, modelReadingText => $chapter->{modelReadingText}, modelReadingAudio=>$chapter->{modelReadingAudio}});
}

$p_modelReading_get =<<EOF;
获取范读信息

输入：
	{
		"obj":"modelReading",
		"act":"get"
	}
输出:
	{
		"modelReadingText":"",		范读文字
		"modelReadingAudio":""		范读音频
		"chapterName":"",
		"chapter":""
	}
EOF

sub p_evaluationQuestion_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	my $currentTime = time();
	my $homework = mdb()->get_collection("homework")->find_one({teacherCode=>$pref->{teacherCode}, startTime =>{'$lt'=>$currentTime}, finishTime =>{'$gt'=>$currentTime}});
	
	if(!$homework){
		return jr() unless assert(0, "暂无课程", "暂无课程", "暂无课程");
	}
	
	my $chapter = mdb()->get_collection("chapter")->find_one({_id=>$homework->{chapterId}});
	if(!$chapter){
		assert(0,"资源不存在","not found","资源不存在");
	}

	my $category = "导读版";
	if($pref->{freeTrial} ne "是"){
		my $order = mdb()->get_collection("order")->find_one({personId=>$gs->{pid}, booksId=>$chapter->{booksId}, Order_Status=>"已完成"});
		if(!$order){
			return jr() unless assert(0,"未购买此图书","未购买此图书","未购买此图书");
		}
		$category = $order->{category};
	}
	
	if($category ne "导读版"){
		return jr() unless assert(0,"导读版才有章节评测题","导读版才有章节评测题","导读版才有章节评测题");
	}
	
	my $Schedule = mdb()->get_collection("chapterSchedule")->find_one({studentId=>$gs->{pid},chapterID=>$chapter->{_id}});
	if(!$Schedule or ($Schedule->{silentReadingState} ne "已完成" and $Schedule->{readingAloudState} ne "已完成")){
		return jr() unless assert(0, "阅读顺序错误", "阅读顺序错误", "阅读顺序错误");
	}
	
    return jr({evaluationQuestion => $chapter->{evaluationQuestion}, chapterId=>$chapter->{_id}});
}

$p_evaluationQuestion_get =<<EOF;
获取章节评测题

输入：
	{
		"obj":"evaluationQuestion",
		"act":"get"
	}
输出：
	{
		"evaluationQuestion":,
		"chapterId":
	}
EOF

sub p_studentScore_set{
	return jr() unless assert($gr->{scoreType},"scoreType 参数少了","scoreType","scoreType 参数少了");
	return jr() unless assert($gr->{sorceList},"sorceList 参数少了","sorceList","sorceList 参数少了");
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");

	my @sorceList = @{$gr->{sorceList}};
	my $sorceCount = @sorceList;
	if($sorceCount <= 0){
		return jr() unless assert(0,"sorceList 参数错误","sorceList","sorceList 参数错误");
	}
	#if($gr->{scoreType} eq "默读" or $gr->{scoreType} eq "朗读" or $gr->{scoreType} eq "默读测试题"){	
	#	return jr() unless assert($gr->{pageSpacing},"pageSpacing 参数少了","pageSpacing","pageSpacing 参数少了");
	#}

	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	my $currentTime = time();
	my $homework = mdb()->get_collection("homework")->find_one({teacherCode=>$pref->{teacherCode}, startTime =>{'$lt'=>$currentTime}, finishTime =>{'$gt'=>$currentTime}});
	
	if(!$homework){
		return jr() unless assert(0, "暂无课程", "暂无课程", "暂无课程");
	}
	
	my $chapter = mdb()->get_collection("chapter")->find_one({_id=>$homework->{chapterId}});
	if(!$chapter){
		return jr() unless assert(0,"资源不存在","not found","资源不存在");
	}
	
	my $chapterSchedule = mdb()->get_collection("chapterSchedule")->find_one({studentId=>$gs->{pid}, chapterID=>$homework->{chapterId}});
	
	if(!$chapterSchedule){
		return jr() unless assert(0,"未开始阅读,无法填写成绩","未开始阅读","未开始阅读");
	}
	
	if($gr->{scoreType} eq "导读"){	
		$chapterSchedule->{guideReadingScore} = $sorceList[0];
		$chapterSchedule->{guideReadingState} = "已完成";
	}elsif($gr->{scoreType} eq "范读"){
		$chapterSchedule->{modelReadingScore} = $sorceList[0];
		$chapterSchedule->{modelReadingState} = "已完成";
	}elsif($gr->{scoreType} eq "评测题"){
		$chapterSchedule->{testQuestionsScore} = $sorceList[0];
		
		$chapterSchedule->{finishTime} = time();
		$chapterSchedule->{readingState} = "已完成";
		
		my $days = days_calculate($chapterSchedule->{startTime}, $chapterSchedule->{finishTime});
		
		$chapterSchedule->{readDays} = $days;
		
		my $readingInfo = mdb()->get_collection("readingInfo")->find_one({chapterID=>$chapter->{_id}});
		if($readingInfo){
			$readingInfo->{finishTime} = time();
			$readingInfo->{readingState} = "已完成";
			my $days = days_calculate($readingInfo->{startTime}, $readingInfo->{finishTime});
			$readingInfo->{readDays} = $days;
		}
		
		$chapterSchedule->{testQuestionsState} = "已完成";
	}elsif($gr->{scoreType} eq "朗读"){
		my @readingAloudSorce = @{$chapterSchedule->{readingAloudSorce}};
		my $count = @readingAloudSorce;
		if($count > 0){
			@readingAloudSorce = sort {$a->{pageIndex} <=> $b->{pageIndex}} @readingAloudSorce;
		}
		
		my $totalSorce = 0;
		for (my $index = 0 ; $index < $sorceCount; $index = $index + 1){
			$readingAloudSorce[$index]->{pageIndex} = $index + 1;
			
			$readingAloudSorce[$index]->{readingAloudFinallyScore} = $sorceList[$index];
			
			if($readingAloudSorce[$index]->{readingAloudCount} == 0){
				$readingAloudSorce[$index]->{readingAloudFirstScore} = $sorceList[$index];
			}

			if($readingAloudSorce[$index]->{readingAloudHighestScore} < $sorceList[$index]){
				$readingAloudSorce[$index]->{readingAloudHighestScore} = $sorceList[$index];
			}
			$readingAloudSorce[$index]->{readingAloudCount} += 1;
			
			$totalSorce += $sorceList[$index];
		}
		
		if($totalSorce != 0 and $sorceCount != 0){
			$totalSorce = $totalSorce / $sorceCount;
		}else{
			$totalSorce = 0;
		}
		
		$chapterSchedule->{readingAloudSorce} = \@readingAloudSorce;
		$chapterSchedule->{readingAloudState} = "已完成";
		$chapterSchedule->{readingAloudTotalSorce} = $totalSorce;
		
		my $chapterNumPre = 0;
		if($chapterSchedule->{chapterNum} > 1){
			$chapterNumPre = $chapterSchedule->{chapterNum} - 1;
		}
		my $chapterSchedulePre = mdb()->get_collection("chapterSchedule")->find_one({studentId=>$gs->{pid}, booksId=>$homework->{booksId}, chapterNum=>$chapterNumPre});
	
		if($chapterSchedulePre){
			$chapterSchedule->{readingAloudProgress} = $chapterSchedule->{readingAloudTotalSorce} - $chapterSchedulePre->{readingAloudTotalSorce};
		}
	}
	
	obj_write($chapterSchedule);

    return jr();
}

$p_studentScore_set =<<EOF;
填写学生导读,范读,朗读,评测题成绩

输入：
	{
		"obj":"studentScore",
		"act":"set",
		"scoreType":"",				导读,范读,朗读,评测题
		"sorceList":				朗读有多个成员,并且按照页码顺序填写,其他的只有一个成员
	}
EOF

sub p_silentReadingScore_set{
	return jr() unless assert($gr->{sorceList},"sorceList 参数少了","sorceList","sorceList 参数少了");
	
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my @sorceList = @{$gr->{sorceList}};
	my $sorceCount = @sorceList;
	if($sorceCount <= 0){
		return jr() unless assert(0,"sorceList 参数错误","sorceList","sorceList 参数错误");
	}
	#if($gr->{scoreType} eq "默读" or $gr->{scoreType} eq "朗读" or $gr->{scoreType} eq "默读测试题"){	
	#	return jr() unless assert($gr->{pageSpacing},"pageSpacing 参数少了","pageSpacing","pageSpacing 参数少了");
	#}

	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	my $currentTime = time();
	my $homework = mdb()->get_collection("homework")->find_one({teacherCode=>$pref->{teacherCode}, startTime =>{'$lt'=>$currentTime}, finishTime =>{'$gt'=>$currentTime}});
	
	if(!$homework){
		return jr() unless assert(0, "暂无课程", "暂无课程", "暂无课程");
	}
	
	my $chapter = mdb()->get_collection("chapter")->find_one({_id=>$homework->{chapterId}});
	if(!$chapter){
		return jr() unless assert(0,"资源不存在","not found","资源不存在");
	}
	
	my $chapterSchedule = mdb()->get_collection("chapterSchedule")->find_one({studentId=>$gs->{pid}, chapterID=>$chapter->{_id}});
	
	if(!$chapterSchedule){
		return jr() unless assert(0,"未开始阅读,无法填写成绩","未开始阅读","未开始阅读");
	}
	
	my %silentReadingScore = %{$chapterSchedule->{silentReadingScore}};
	
	my $totalSorce = 0;
	my $totalAnswerTime = 0;
	foreach my $item(@sorceList){
		$silentReadingScore{$item->{pageSpacing}} = $item;
		
		if($item->{testQuestions} eq "优"){
			$totalSorce += 5;
		}elsif($item->{testQuestions} eq "良"){
			$totalSorce += 2.5;
		}elsif($item->{testQuestions} eq "不合格"){
			$totalSorce += 0;
		}
		
		$totalAnswerTime += $item->{answerTime};
	}
	$chapterSchedule->{silentReadingState} = "已完成";
	
	#计算默读总成绩  评测题平均成绩
	$totalSorce = $totalSorce / $sorceCount;
	if($totalSorce < 2){
		$chapterSchedule->{silentReadingTotalSorce} = "不合格";
	}elsif($totalSorce  > 3){
		$chapterSchedule->{silentReadingTotalSorce} = "优";
	}else{
		$chapterSchedule->{silentReadingTotalSorce} = "良";
	}

	#计算默读平均用时
	$totalAnswerTime = $totalAnswerTime / $sorceCount;
	$chapterSchedule->{silentReadingAnswerTime} = $totalAnswerTime;
	
	obj_write($chapterSchedule);

    return jr();
}

$p_silentReadingScore_set =<<EOF;
填写学生默读成绩

输入：
	{
		"obj":"silentReadingScore",
		"act":"set",
		"sorceList":[
			{
				"pageSpacing":1				页码
				"sorce":12					默读成绩
				"testQuestions":123			默读测试题成绩
				"answerTime":12				默读答题时间
			},
			{
				"pageSpacing":1
				"sorce":12
				"testQuestions":123
				"answerTime":12
			}
		]
	}
EOF

sub p_readingAloudScore_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	my $currentTime = time();
	my $homework = mdb()->get_collection("homework")->find_one({teacherCode=>$pref->{teacherCode}, startTime =>{'$lt'=>$currentTime}, finishTime =>{'$gt'=>$currentTime}});
	
	if(!$homework){
		return jr() unless assert(0, "暂无课程", "暂无课程", "暂无课程");
	}
	
	my $chapterSchedule = mdb()->get_collection("chapterSchedule")->find_one({studentId=>$gs->{pid}, chapterID=>$homework->{chapterId}});
	
	if(!$chapterSchedule){
		return jr() unless assert(0,"未开始阅读","未开始阅读","未开始阅读");
	}
	
	my @score = @{$chapterSchedule->{readingAloudSorce}};

	@score = sort { $a->{pageIndex} <=> $b->{pageIndex} } @score;
	
	my $aver = 0;
	my $count = @score;
	
	foreach my $item(@score){
		$aver += $item->{readingAloudHighestScore};
	}
	
	if($count != 0 and $aver != 0){
		$aver = $aver / $count;
	}else{
		$aver = 0;
	}
	
	return jr({readingAloudScore=>\@score, averageScore=>$aver});
}

$p_readingAloudScore_get =<<EOF;
学生端获取朗读成绩

输入:
	{
		"obj":"readingAloudScore",
		"act":"get"
	}
输出:
	{
		"readingAloudScore":[],
		"averageScore":
	}
EOF

sub p_chapterScore_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	my $currentTime = time();
	my $homework = mdb()->get_collection("homework")->find_one({teacherCode=>$pref->{teacherCode}, startTime =>{'$lt'=>$currentTime}, finishTime =>{'$gt'=>$currentTime}});
	
	if(!$homework){
		return jr() unless assert(0, "暂无课程", "暂无课程", "暂无课程");
	}
	
	my $chapterSchedule = mdb()->get_collection("chapterSchedule")->find_one({studentId=>$gs->{pid}, chapterID=>$homework->{chapterId}});
	
	if(!$chapterSchedule){
		return jr() unless assert(0,"未开始阅读","未开始阅读","未开始阅读");
	}
	
	#return jr({guideReadingScore=>$chapterSchedule->{guideReadingScore}, modelReadingScore=>$chapterSchedule->{modelReadingScore}, readingAloudTotalSorce=>$chapterSchedule->{readingAloudTotalSorce}, silentReadingTotalSorce=>$chapterSchedule->{silentReadingTotalSorce},testQuestionsScore=>$chapterSchedule->{testQuestionsScore}});
	
	return jr({chapterSchedule=> $chapterSchedule});
}

$p_chapterScore_get =<<EOF;
学生端获取章节成绩

输入:
	{
		"obj":"chapterScore",
		"act":"get"
	}
输出:
	{
		"chapterSchedule":
	}
EOF

sub p_accuracy_Calculation{
	return jr() unless assert($gr->{original},"original 参数少了","original","original 参数少了");
	return jr() unless assert($gr->{transcript},"transcript 参数少了","transcript","transcript 参数少了");
	
	my %originalPhrase;				#原文词组
	my %transcriptPhrase;			#默读词组
	
	my $originalLength = length($gr->{original});
	for(my $i = 0; $i < $originalLength; $i = $i+ 1){
		my $phrase = substr($gr->{original},$i,1);
		
		if(exists($originalPhrase{$phrase})){
			#已经存在
			$originalPhrase{$phrase} = $originalPhrase{$phrase} + 1;
		}
		else{
			#不存在
			$originalPhrase{$phrase} = 1;
		}
	}
	
	for(my $i = 0; $i < length($gr->{transcript}); $i++){
		my $phrase = substr($gr->{transcript},$i,1);
		
		if( exists($transcriptPhrase{$phrase} ) ){
			#已经存在
			$transcriptPhrase{$phrase} = $transcriptPhrase{$phrase} + 1;
		}
		else{
			#不存在
			$transcriptPhrase{$phrase} = 1;
		}
	}
	
	my $total = 0;
	@originalKeys = keys %originalPhrase;
	foreach $item (@originalKeys){
		#abs
		my $count = abs($originalPhrase{$item} - $transcriptPhrase{$item});
		$total = $total + $count;
	}
	
	my $res = $total / $originalLength;
	
	$res = 1.0 - $res;
	$res = $res * 5;#最多五颗星
	
    return jr({res => $res});
}

$p_accuracy_Calculation =<<EOF;
计算正确率

输入：
	{
		"obj":"accuracy",
		"act":"Calculation",
		"original":"",					原文
		"transcript":""					默读识别出的文本
	}
EOF

sub readingInfo_set{
	return jr() unless assert($gr->{id},"id 参数少了","id","id 参数少了");
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my $chapter = mdb()->get_collection("chapter")->find_one({_id=>$gr->{id}});

	if(!$chapter){
		return assert(0,"资源不存在","not found","资源不存在");
	}

	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	my $readingInfo = mdb()->get_collection("readingInfo")->find_one({chapterID=>$chapter->{_id}});
	if(!$readingInfo){
		$readingInfo->{_id} = obj_id();
		$readingInfo->{type} = "readingInfo";
		$readingInfo->{teacherCode} = $pref->{teacherCode};
		$readingInfo->{booksId} = $chapter->{booksId};
		$readingInfo->{bookName} = $chapter->{name};
		$readingInfo->{chapterPage} = $chapter->{chapterPage};
		$readingInfo->{chapterID} = $chapter->{_id};
		$readingInfo->{chapterName} = $chapter->{name};
		$readingInfo->{startTime} = time();
		$readingInfo->{finishTime} = 0;
		$readingInfo->{readDays} = 0;
		$readingInfo->{readingState} = "阅读中";
	}
	obj_write($readingInfo);
	
	my $Schedule = mdb()->get_collection("chapterSchedule")->find_one({studentId=>$gs->{pid},chapterID=>$chapter->{_id}});
	if(!$Schedule){
		$Schedule->{_id} = obj_id();
		$Schedule->{teacherCode} = $pref->{teacherCode};
		$Schedule->{type} = "chapterSchedule";
		$Schedule->{studentId} = $gs->{pid};
		$Schedule->{studentName} = $pref->{name};
		$Schedule->{booksId} = $chapter->{booksId};
		$Schedule->{bookName} = $chapter->{name};
		$Schedule->{chapterPage} = $chapter->{chapterPage};
		$Schedule->{chapterID} = $chapter->{_id};
		$Schedule->{chapterName} = $chapter->{name};
		$Schedule->{chapterNum} = $chapter->{chapterNum};
		$Schedule->{startTime} = time();
		$Schedule->{finishTime} = 0;
		$Schedule->{readDays} = 0;
		$Schedule->{readingState} = "阅读中";
	}
	obj_write($Schedule);
	
	return $Schedule;
}

sub p_currentHomework_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	#my @scheduleList = mdb()->get_collection("chapterSchedule")->find({studentId=>$gs->{pid}})->all();
	
	my $currentTime = time();
	my $homework = mdb()->get_collection("homework")->find_one({teacherCode=>$pref->{teacherCode}, startTime =>{'$lt'=>$currentTime}, finishTime =>{'$gt'=>$currentTime}});
	
	if(!$homework){
		return jr() unless assert(0, "暂无课程", "暂无课程", "暂无课程");
	}
	
	my $chapterSchedule = mdb()->get_collection("chapterSchedule")->find_one({chapterID=>$homework->{chapterId}, studentId=>$pref->{_id}});
	
	#$homework->{}
	
	return jr({homework=>$homework, chapterSchedule=>$chapterSchedule});
}

$p_currentHomework_get =<<EOF;
学生端获取当前作业章节信息

输入：
	{
		"obj":"currentHomework",
		"act":"get"
	}
输入：
	{
		"homework":"",
		"chapterSchedule":""
	}
EOF

sub p_homework_share{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	my $ImageCount = @{$gr->{shareImageList}};
	my $AudioCount = @{$gr->{shareAudioList}};
	my $VideoCount = @{$gr->{shareVideoList}};
	
	if(!length($gr->{shareText}) and $ImageCount == 0 and $AudioCount == 0 and $VideoCount == 0){
		return jr() unless assert(0, "分享数据不能为空", "分享数据不能为空", "分享数据不能为空");
	}
	
	my $currentTime = time();
	my $homework = mdb()->get_collection("homework")->find_one({teacherCode=>$pref->{teacherCode}, startTime =>{'$lt'=>$currentTime}, finishTime =>{'$gt'=>$currentTime}});
	
	if(!$homework){
		return jr() unless assert(0, "暂无课程", "暂无课程", "暂无课程");
	}
	
	my $chapter = mdb()->get_collection("chapter")->find_one({_id=>$homework->{chapterId}});
	if(!$chapter){
		return jr() unless assert(0,"资源不存在","not found","资源不存在");
	}
	
	my $Schedule = mdb()->get_collection("chapterSchedule")->find_one({studentId=>$gs->{pid},chapterID=>$chapter->{_id}});
	
	if(!$Schedule){
		return jr() unless assert(0,"未开始阅读","未开始阅读","未开始阅读");
	}
	
	my $homeworkShare = {
		_id => obj_id(),
		type => "homeworkShare",
		category => $homework->{category},
		avatarFid => $pref->{avatar_fid},
		studentId => $gs->{pid},
		studentName => $pref->{name},
		teacherCode => $pref->{teacherCode},
		booksId => $Schedule->{booksId},
		bookName => $chapter->{name},
		chapterID => $chapter->{_id},
		chapterName => $chapter->{name},
		pageSpacing => $Schedule->{chapterPage},
		guideReadingScore => $Schedule->{guideReadingScore},
		modelReadingScore => $Schedule->{modelReadingScore},
		testQuestionsScore => $Schedule->{testQuestionsScore},
		readingAloudScore => $Schedule->{readingAloudTotalSorce},
		silentReadingScore => $Schedule->{silentReadingTotalSorce},
		shareText => $gr->{shareText},
		shareImageList => $gr->{shareImageList},
		shareAudioList => $gr->{shareAudioList},
		shareVideoList => $gr->{shareVideoList},
		uploadTime => time(),
	};
	obj_write($homeworkShare);
	
	#记录个人的章节成绩 by wallent
	my $homeworkSharePersonal=mdb()->get_collection("homeworkSharePersonal")->find_one({studentId=>$gs->pid,booksId=>$Schedule->{booksId}});
	if(defined($homeworkShare))
	{
		 
	}
	else
	{
		my $homeworkSharePersonal=
		{
			_id=>obj_id(),
			type=>"homeworkSharePersonal",
			teacherCode=>$pref->{teacherCode},
			studentId=>$gs->{pid},
			booksId => $Schedule->{booksId},
			scores=>[],
			total_guide=>0,
			total_model=>0,
			total_test=>0,
			total_read=>0,
			total_slient=>0,
			total_all=>0,
			 
		};	
	}
	
		my @inter={
			chaperId=>$chapter->{_id},
			guideReadingScore => $Schedule->{guideReadingScore},
			modelReadingScore => $Schedule->{modelReadingScore},
			testQuestionsScore => $Schedule->{testQuestionsScore},
			readingAloudScore => $Schedule->{readingAloudTotalSorce},
			silentReadingScore => $Schedule->{silentReadingTotalSorce},
		};
		push  $homeworkSharePersonal->{scores},@inter;
		$homeworkSharePersonal->{total_guide}=$homeworkSharePersonal->{total_guide}+$Schedule->{guideReadingScore};
		$homeworkSharePersonal->{total_model}=$homeworkSharePersonal->{total_model}+$Schedule->{modelReadingScore};
		$homeworkSharePersonal->{total_test}=$homeworkSharePersonal->{total_test}+$Schedule->{testQuestionsScore};
		$homeworkSharePersonal->{total_read}=$homeworkSharePersonal->{total_read}+$Schedule->{readingAloudTotalSorce};
		$homeworkSharePersonal->{total_slient}=$homeworkSharePersonal->{total_slient}+$Schedule->{silentReadingTotalSorce};
		$homeworkSharePersonal->{total_all}=$homeworkSharePersonal->{total_all}
		+$Schedule->{guideReadingScore}
		+$Schedule->{modelReadingScore}
		+$Schedule->{testQuestionsScore}
		+$Schedule->{readingAloudTotalSorce}
		+$Schedule->{silentReadingTotalSorce}
		;
		
		obj_write($homeworkSharePersonal);
	

    return jr();
}

$p_homework_share =<<EOF;
学生端分享作业

输入：
	{
		"obj":"homework",
		"act":"share",
		"shareText":"",				文本
		"shareImageList":[],		图片列表
		"shareAudioList":[			音频列表
			{
				audioDuration:		音频时长
				audioFid:			音频文件id
			}
		],
		"shareVideoList":[			视频列表
			{
				videoThumbnailFid:	视频截图
				videoFid:			视频文件id
			}
		]
	}
EOF

sub p_homeworkShare_delete{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{homeworkId}, "homeworkId 参数少了", "homeworkId 参数少了", "homeworkId 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	my $homeworkShare = mdb()->get_collection("homeworkShare")->find_one({_id=>$gr->{homeworkId}});
	if(!$homeworkShare){
		return jr() unless assert(0, "homeworkId 参数错误", "homeworkId 参数错误", "homeworkId 参数错误");
	}
	
	if($pref->{position} ne "teacher"){
		if($pref->{_id} ne $homeworkShare->{studentId}){
			return jr() unless assert(0, "学生只能删除自己的作业", "学生只能删除自己的作业", "学生只能删除自己的作业");
		}
	}
	
	obj_delete("homeworkShare", $gr->{homeworkId});

    return jr();
}

$p_homeworkShare_delete =<<EOF;
删除学生分享的作业

输入：
	{
		"obj":"homeworkShare",
		"act":"delete",
		"homeworkId":""
	}
EOF

sub p_sharedByEveryone_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{style},"style 参数少了","style","style 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	my $limit = $gr->{limit};
	$limit = 12 unless $limit;
	
	my $page = $gr->{page};
	$page = 1 unless $page;
	my $skipCount = ($page - 1) * $limit;
	
	my @shareList = ();
	if($gr->{style} eq "group"){
		my $group = mdb()->get_collection("classGroup")->find_one({teacherCode=>$pref->{teacherCode}});
		my @groupList = $group->{groupList};
		my @currentList = ();
		foreach my $item(@groupList){
			foreach my $studentItem(@{$item->{studentList}}){
				if($studentItem->{studentId} eq $pref->{_id}){
					@currentList = @{$item->{studentList}};
					last;
				}
			}
		}
		
		my $listCount = @currentList;
		if($listCount <= 0){
			return jr() unless assert(0, "学生没有在任何分组中", "学生没有在任何分组中", "学生没有在任何分组中");
		}
		
		my %orData = ('$or'=>"or");
		my @orArray = ();
		
		foreach my $item(@currentList){
			my $orStudent = {
				_id => $item->{studentId}
			};
			
			push @orArray, $orStudent;
		}
		
		$orData{'$or'} = @orArray;
		@shareList = mdb()->get_collection("homeworkShare")->find(\%orData)->limit($limit)->skip($skipCount)->sort({"uploadTime"=>-1})->all();
	}else{
		#sort 以index字段排序,1为升序,-1为降序
		@shareList = mdb()->get_collection("homeworkShare")->find({teacherCode=>$pref->{teacherCode}})->limit($limit)->skip($skipCount)->sort({"uploadTime"=>-1})->all();
	}

	foreach my $item (@shareList){
		my @praiseList = mdb()->get_collection("praise")->find({homeworkId=>$item->{_id}})->sort({"praiseTime"=>1})->all();
		
		$item->{praiseList} = @praiseList;
		
		my @commentList = mdb()->get_collection("comment")->find({homeworkId=>$item->{_id}})->sort({"commentTime"=>1})->all();
		
		$item->{commentList} = @commentList;
	}
	
    return jr({shareList=>\@shareList});
}

$p_sharedByEveryone_get =<<EOF;
学生端获取大家的分享

输入：
	{
		"obj":"sharedByEveryone",
		"act":"get",
		"style":"",				(class/group)(根据小组显示还是全班显示)
		"page":1,				(默认为1,既,第一页)
		"limit":12				(默认为12,既,每次请求十条数据)
	}
输出:
	{
		"shareList":[]
	}
EOF

sub p_myShared_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	#my $pref = obj_read("person", $gs->{pid});
	#if(!$pref){
	#	return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	#}
	
	my $limit = $gr->{limit};
	$limit = 12 unless $limit;
	
	my $page = $gr->{page};
	$page = 1 unless $page;
	my $skipCount = ($page - 1) * $limit;
	
	#sort 以index字段排序,1为升序,-1为降序
	my @shareList = mdb()->get_collection("homeworkShare")->find({studentId=>$gs->{pid}})->limit($limit)->skip($skipCount)->sort({"uploadTime"=>-1})->all();

	foreach my $item (@shareList){
		my @praiseList = mdb()->get_collection("praise")->find({homeworkId=>$item->{_id}})->sort({"praiseTime"=>1})->all();
		
		$item->{praiseList} = @praiseList;
		
		my @commentList = mdb()->get_collection("comment")->find({homeworkId=>$item->{_id}})->sort({"commentTime"=>1})->all();
		
		$item->{commentList} = @commentList;
	}
	
    return jr({shareList=>\@shareList});
}

$p_myShared_get =<<EOF;
学生端获取我的分享

输入:
	{
		"obj":"myShared",
		"act":"get",
		"page":1,					(默认为1,既,第一页)
		"limit":12					(默认为12,既,每次请求十条数据)
	}
输出:
	{
		"shareList":[]
	}
EOF

sub p_studentInfo_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	my $name = $pref->{name};
	#if($pref->{display_name} eq $pref->{login_name}){
	#	$name = "";
	#}
	
	my $sex = $pref->{sex};
	$sex = "" unless $sex;

    return jr({avatar_fid=>$pref->{avatar_fid}, name=>$name, sex=>$sex, school=>$pref->{school}, grade=>$pref->{grade}, class=>$pref->{class}, account=>$pref->{login_name}});
}

$p_studentInfo_get =<<EOF;
获取用户信息

输入：
	{
		"obj":"studentInfo",
		"act":"get"
	}
输入：
	{
		"avatar_fid":"",
		"name":"",
		"sex":"",
		"school":"",
		"grade":"",
		"class":"",
		"account":""
	}
EOF


sub p_curriculumSchedule_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	#my @scheduleList = mdb()->get_collection("chapterSchedule")->find({studentId=>$gs->{pid}})->all();
	
	my $currentTime = time();
	#my $homework = mdb()->get_collection("homework")->find_one({teacherCode=>$pref->{teacherCode}, startTime =>{'$lt'=>$currentTime}, finishTime =>{'$gt'=>$currentTime}});
	#if(!$homework){
	#	return jr() unless assert(0, "暂无课程", "暂无课程", "暂无课程");
	#}
	
	my @homeworkListTmp = mdb()->get_collection("homework")->find({teacherCode=>$pref->{teacherCode}, finishTime =>{'$gt'=>$currentTime}})->sort({"finishTime"=>1})->all();
	
	if(!scalar(@homeworkListTmp)){
		return jr() unless assert(0, "暂无课程", "暂无课程", "暂无课程");
	}
	
	my $booksId = $homeworkListTmp[0]->{booksId};
	
	homework_update($pref->{teacherCode}, $booksId);
	
	my @homeworkList = mdb()->get_collection("homework")->find({teacherCode=>$pref->{teacherCode}, booksId=>$booksId})->all();
	
    @homeworkList = sort { $a->{pageSpacing} <=> $b->{pageSpacing} } @homeworkList;
	
	return jr({homeworkList=>\@homeworkList});
}

$p_curriculumSchedule_get =<<EOF;
学生端获取课程表

输入：
	{
		"obj":"curriculumSchedule",
		"act":"get"
	}
输入：
	{
		"homeworkList":""
	}
EOF

sub p_booksList_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{position}, "position 参数少了", "position", "position 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	my $limit = $gr->{limit};
	$limit = 12 unless $limit;
	
	my $page = $gr->{page};
	$page = 1 unless $page;
	my $skipCount = ($page - 1) * $limit;
	
	#sort 以index字段排序,1为升序,-1为降序
	#limit 读取的记录条数
	#skip 跳过的记录条数
	
	my $grade = "";
	if($pref->{position} eq "student"){
		$grade = $pref->{grade};
	}
	
	if(length($gr->{searchName})){
		my %data = ();
		my %regex = ('$regex'=>"regex");
		$regex{'$regex'} = $gr->{searchName};
		$data{"name"} = \%regex;
		
		$data{"status"} = "上架";
		
		#if(length($grade)){
		#	$data{"grade"} = $grade;
		#}
		
		#@booksList = mdb()->get_collection("books")->find(\%data)->limit($limit)->skip($skipCount)->sort({"uploadTime"=>-1})->all();
	}
	#else{
	#	if(length($grade)){
	#		@booksList = mdb()->get_collection("books")->find({grade=>$grade})->limit($limit)->skip($skipCount)->sort({"uploadTime"=>-1})->all();
	#	}
	#	else{
	#		@booksList = mdb()->get_collection("books")->find()->limit($limit)->skip($skipCount)->sort({"uploadTime"=>-1})->all();
	#	}
	#}

	my @booksList = mdb()->get_collection("books")->find(\%data)->limit($limit)->skip($skipCount)->sort({"uploadTime"=>-1})->all();
	
	if($gr->{position} eq "teacher"){
		if($gr->{position} ne $pref->{position}){
			return jr() unless assert(0, "position 参数错误", "position", "position 参数错误");
		}
		
		foreach my $item(@booksList){
			my $favourite = mdb()->get_collection("favourite")->find_one({teacherId=>$pref->{_id}, booksId=>$item->{_id}});
			if($favourite){
				$item->{favourite} = "是";
			}else{
				$item->{favourite} = "否";
			}
		}
		#my @collectionList = mdb()->get_collection("favourite")->find({teacherId=>$pref->{_id}})->all();
	}

	return jr({booksList=>\@booksList});
}

$p_booksList_get =<<EOF;
发现课程

输入：
	{
		"obj":"booksList",
		"act":"get",
		"position":"",				teacher/student
		"searchName":"",			搜索也是此接口,传空为全部
		"page":1,					(默认为1,既,第一页)
		"limit":12					(默认为12,既,每次请求十条数据)
	}
输入：
	{
		"booksList":""
	}
EOF

sub p_booksRecommendList_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my @booksList = mdb()->get_collection("books")->find({recommend=>"是", status=>"上架"})->all();
	
	return jr({booksList=>\@booksList});
}

$p_booksRecommendList_get =<<EOF;
学生端发现推荐课程

输入：
	{
		"obj":"booksRecommendList",
		"act":"get"
	}
输入：
	{
		"booksList":""
	}
EOF

sub p_books_check{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{bookId}, "bookId 参数少了", "bookId 参数少了", "bookId 参数少了");
	
	#my $pref = obj_read("person", $gs->{pid});
	#if(!$pref){
	#	return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	#}
	
	my $guideBooksTmp = mdb()->get_collection("order")->find_one({personId=>$gs->{pid}, booksId=>$gr->{bookId}, category=>"导读版", Order_Status=>"已完成"});
	
	my $basicBooksTmp = mdb()->get_collection("order")->find_one({personId=>$gs->{pid}, booksId=>$gr->{bookId}, category=>"基础版", Order_Status=>"已完成"});
	
	my $guide = "否";
	my $basic = "否";
	
	if($guideBooksTmp){
		$guide = "是";
	}
	
	if($basicBooksTmp){
		$basic = "是";
	}
	#if(!$booksTmp){
	#	return jr({alreadyPurchased=>"否"});
	#}
	#return jr({alreadyPurchased=>"是"});
	return jr({guide=>$guide, basic=>$basic});
}

$p_books_check =<<EOF;
学生端检测图书购买状态

输入：
	{
		"obj":"books",
		"act":"check",
		"bookId":""
	}
输入：
	{
		"guide":""		是->已购买,否->没有购买
		"basic":""
	}
EOF

sub p_parentalPassword_set{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if(length($pref->{parentalPassword})){
		return jr() unless assert(0, "已设置家长控制密码", "已设置家长控制密码", "已设置家长控制密码");
	}
	
	$pref->{parentalPassword} = $gr->{password};
	
	obj_write($pref);
}

$p_parentalPassword_set =<<EOF;
学生端家长控制密码设置

输入：
	{
		"obj":"parentalPassword",
		"act":"set",
		"password":""
	}
EOF

sub p_parentalControl_login{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if(!length($pref->{parentalPassword})){
		return jr() unless assert(0, "未设置家长控制", "未设置家长控制", "未设置家长控制");
	}
	
	if($pref->{parentalPassword} eq $gr->{password}){
		$pref->{isParent} = "是";
	}
	
	obj_write($pref);
	return jr();
}

$p_parentalControl_login =<<EOF;
学生端开启家长控制

输入：
	{
		"obj":"parentalControl",
		"act":"login",
		"password":""
	}
EOF

sub p_parentalControl_logout{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if(!length($pref->{parentalPassword})){
		return jr() unless assert(0, "未设置家长控制", "未设置家长控制", "未设置家长控制");
	}
	
	if($pref->{isParent} eq "否"){
		return jr() unless assert(0, "未开启家长控制", "未开启家长控制", "未开启家长控制");
	}
	$pref->{isParent} = "否";
	obj_write($pref);
	return jr();
}

$p_parentalControl_logout =<<EOF;
学生端关闭家长控制

输入：
	{
		"obj":"parentalControl",
		"act":"logout"
	}
EOF

sub p_booksInfo_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{booksId},"booksId 参数少了","booksId","booksId 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	my $books = mdb()->get_collection("books")->find_one({_id=>$gr->{booksId}});
	if(!$books){	
		return jr() unless assert(0,"资源不存在","资源不存在","资源不存在");
	}
	if($books->{status} ne "上架"){	
		return jr() unless assert(0,"该课本已下架","该课本已下架","该课本已下架");
	}
	
	my @chapterList = values %{$books->{ChapterID}};
	
	my @chapterInfoList = ();
	foreach my $item(@chapterList){
		my $chapter = mdb()->get_collection("chapter")->find_one({_id=>$item});
		if($chapter){
			my $chapterTmp = {
				_id => $chapter->{_id},
				name => $chapter->{name},
				startPage => $chapter->{startPage},
				endPage => $chapter->{endPage},
				chapterNum => $chapter->{chapterNum},
			};
			push @chapterInfoList, $chapterTmp;
		}
	}
	my @chapterInfoListTmp = sort { $a->{chapterNum} <=> $b->{chapterNum} } @chapterInfoList if(scalar @chapterInfoList);
	#return jr({homeworkList=>\@homeworkListTmp});
	
	$books->{chapterList} = \@chapterInfoListTmp;
	return jr({books=>$books});
}

$p_booksInfo_get =<<EOF;
获取课本详细信息

输入：
	{
		"obj":"booksInfo",
		"act":"get",
		"booksId":""
	}
输出：
	{
		"books":""
	}
EOF

sub p_classAnnouncement_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}

	my @classAnnouncementList = mdb()->get_collection("classAnnouncement")->find({teacherCode=>$pref->{teacherCode}})->sort({"createTime"=>-1})->all();
	
	my $classAnnouncement = $classAnnouncementList[0];
	
	return jr({classAnnouncement=>$classAnnouncement});
}

$p_classAnnouncement_get =<<EOF;
获取班级公告

输入：
	{
		"obj":"classAnnouncement",
		"act":"get"
	}
输出：
	{
		"classAnnouncement":
	}
EOF

#sub p_leaderboard_get{
#	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
#	
#	my $pref = obj_read("person", $gs->{pid});
#	if(!$pref){
#		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
#	}
#	
#	my $currentTime = time();
#	my $homework = mdb()->get_collection("homework")->find_one({teacherCode=>$pref->{teacherCode}, startTime =>{'$lt'=>$currentTime}, finishTime =>{'$gt'=>$currentTime}});
#	
#	if(!$homework){
#		return jr() unless assert(0, "暂无课程", "暂无课程", "暂无课程");
#	}
#	
#	my $chapter = mdb()->get_collection("chapter")->find_one({_id=>$homework->{chapterId}});
#	if(!$chapter){
#		return jr() unless assert(0,"资源不存在","not found","资源不存在");
#	}
#	
#	my @studentRes = mdb()->get_collection("person")->find({teacherCode=>$gr->{teacherCode}})->all();
#	
#	my $studentCount = @studentRes;
#	my $topCount = $studentCount * 0.7 - 10;#班级前70%的学生人数
#	
#	my @studentList = ();
#	
#	if($homework->{readType} eq "朗读"){
#		#班级前十
#		my @topTen = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$pref->{teacherCode}, chapterID=>$homework->{chapterId}})->sort({"readingAloudTotalSorce"=>-1})->limit(10)->all();
#		
#		foreach my $item (@topTen){
#			my $personTmp = mdb()->get_collection("person")->find_one({_id=>$item->{studentId}});
#			
#			my $studentTmp = {
#				name => $personTmp->{name},
#				avatar_fid => $personTmp->{avatar_fid},
#				sex => $personTmp->{sex},
#			};
#			
#			push @studentList,$studentTmp;
#		}
#		
#		if($chapter->{chapterNum} > 1){
#			#第一章不需要计算
#			#进步前五
#			my @progressList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$pref->{teacherCode}, chapterID=>$homework->{chapterId}})->sort(readingAloudProgress=>-1)->limit(5)->all();
#			
#			foreach my $item (@progressList){
#				my $personTmp = mdb()->get_collection("person")->find_one({_id=>$item->{studentId}});
#				
#				my $studentTmp = {
#					name => $personTmp->{name},
#					avatar_fid => $personTmp->{avatar_fid},
#					sex => $personTmp->{sex},
#				};
#				
#				push @studentList, $studentTmp;
#			}
#		}
#		
#		my $totalStudent = @studentList;
#		if($totalStudent < $topCount){
#			my $insufficient = $topCount - $totalStudent;
#			
#			#前十的已经添加,故,前70%的,去除前十的
#			my @ClassRanking = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$pref->{teacherCode}, chapterID=>$homework->{chapterId}})->sort(readingAloudTotalSorce=>-1)->limit($topCount)->skip(10)->all();
#			
#			for(my $index = 0; $index < $insufficient;$index += 1){
#				my $personTmp = mdb()->get_collection("person")->find_one({_id=>$ClassRanking[$index]->{studentId}});
#				
#				my $studentTmp = {
#					name => $personTmp->{name},
#					avatar_fid => $personTmp->{avatar_fid},
#					sex => $personTmp->{sex},
#				};
#				
#				push @studentList, $studentTmp;
#			}
#		}
#	}elsif($homework->{readType} eq "朗读"){
#		my @slientReadingList = ();
#		my @excellentList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$pref->{teacherCode}, chapterID=>$homework->{chapterId}, silentReadingTotalSorce=>"优"})->sort({"silentReadingAnswerTime"=>1})->all();
#		
#		@slientReadingList = @excellentList;
#		$totalSlientCount = @excellentList;
#		if($totalSlientCount < $topCount){
#			my @goodList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$pref->{teacherCode}, chapterID=>$homework->{chapterId}, silentReadingTotalSorce=>"良"})->sort({"silentReadingAnswerTime"=>1})->all();
#			
#			@slientReadingList = (@slientReadingList, @goodList);
#		}
#		
#		$totalSlientCount = @slientReadingList;
#		if($totalSlientCount < $topCount){
#			my @failedList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$pref->{teacherCode}, chapterID=>$homework->{chapterId}, silentReadingTotalSorce=>"不合格"})->sort({"silentReadingAnswerTime"=>1})->all();
#			
#			@slientReadingList = (@slientReadingList, @failedList);
#		}
#		
#		my $slientCount = 0;
#		foreach my $item (@slientReadingList){
#			my $personTmp = mdb()->get_collection("person")->find_one({_id=>$item->{studentId}});
#			
#			my $studentTmp = {
#				name => $personTmp->{name},
#				avatar_fid => $personTmp->{avatar_fid},
#				sex => $personTmp->{sex},
#			};
#			
#			push @studentList, $studentTmp;
#			$slientCount += 1;
#			if($slientCount == $topCount){
#				last;
#			}
#		}
#	}
#	
#	return jr({leaderboard=>\@studentList});
#}

sub p_leaderboard_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{chapterId}, "chapterId 参数少了", "chapterId", "chapterId 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	my $chapter = mdb()->get_collection("chapter")->find_one({_id=>$gr->{chapterId}});
	if(!$chapter){
		return jr() unless assert(0,"资源不存在","not found","资源不存在");
	}

	my $homework = mdb()->get_collection("homework")->find_one({chapterId=>$gr->{chapterId}});
	if(!$homework){
		return jr() unless assert(0, "暂无课程", "暂无课程", "暂无课程");
	}
	
	if($homework->{finishTime} gt time()){
		return jr() unless assert(0, "该章节课程尚未结束", "该章节课程尚未结束", "该章节课程尚未结束");
	}
	
	my @studentList = ();
	my $leaderboard = mdb()->get_collection("leaderboard")->find_one({homeworkId=>$homework->{_id}});
	if(!$leaderboard){
		my @studentRes = mdb()->get_collection("person")->find({teacherCode=>$pref->{teacherCode}})->all();
		
		my $studentCount = @studentRes;
		my $topCount = $studentCount * 0.7 - 10;#班级前70%的学生人数
		
		if($homework->{readType} eq "朗读"){
			#班级前十
			my @topTen = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$pref->{teacherCode}, chapterID=>$homework->{chapterId}})->sort({"readingAloudTotalSorce"=>-1})->limit(10)->all();
			
			foreach my $item (@topTen){
				my $personTmp = mdb()->get_collection("person")->find_one({_id=>$item->{studentId}});
				
				my $studentTmp = {
					name => $personTmp->{name},
					avatar_fid => $personTmp->{avatar_fid},
					sex => $personTmp->{sex},
				};
				
				push @studentList,$studentTmp;
			}
			
			if($chapter->{chapterNum} > 1){
				#第一章不需要计算
				#进步前五
				my @progressList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$pref->{teacherCode}, chapterID=>$homework->{chapterId}})->sort(readingAloudProgress=>-1)->limit(5)->all();
				
				foreach my $item (@progressList){
					my $personTmp = mdb()->get_collection("person")->find_one({_id=>$item->{studentId}});
					
					my $studentTmp = {
						name => $personTmp->{name},
						avatar_fid => $personTmp->{avatar_fid},
						sex => $personTmp->{sex},
					};
					
					push @studentList, $studentTmp;
				}
			}
			
			my $totalStudent = @studentList;
			if($totalStudent < $topCount){
				my $insufficient = $topCount - $totalStudent;
				
				#前十的已经添加,故,前70%的,去除前十的
				my @ClassRanking = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$pref->{teacherCode}, chapterID=>$homework->{chapterId}})->sort(readingAloudTotalSorce=>-1)->limit($topCount)->skip(10)->all();
				
				for(my $index = 0; $index < $insufficient;$index += 1){
					my $personTmp = mdb()->get_collection("person")->find_one({_id=>$ClassRanking[$index]->{studentId}});
					
					my $studentTmp = {
						name => $personTmp->{name},
						avatar_fid => $personTmp->{avatar_fid},
						sex => $personTmp->{sex},
					};
					
					push @studentList, $studentTmp;
				}
			}
		}elsif($homework->{readType} eq "朗读"){
			my @slientReadingList = ();
			my @excellentList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$pref->{teacherCode}, chapterID=>$homework->{chapterId}, silentReadingTotalSorce=>"优"})->sort({"silentReadingAnswerTime"=>1})->all();
			
			@slientReadingList = @excellentList;
			$totalSlientCount = @excellentList;
			if($totalSlientCount < $topCount){
				my @goodList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$pref->{teacherCode}, chapterID=>$homework->{chapterId}, silentReadingTotalSorce=>"良"})->sort({"silentReadingAnswerTime"=>1})->all();
				
				@slientReadingList = (@slientReadingList, @goodList);
			}
			
			$totalSlientCount = @slientReadingList;
			if($totalSlientCount < $topCount){
				my @failedList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$pref->{teacherCode}, chapterID=>$homework->{chapterId}, silentReadingTotalSorce=>"不合格"})->sort({"silentReadingAnswerTime"=>1})->all();
				
				@slientReadingList = (@slientReadingList, @failedList);
			}
			
			my $slientCount = 0;
			foreach my $item (@slientReadingList){
				my $personTmp = mdb()->get_collection("person")->find_one({_id=>$item->{studentId}});
				
				my $studentTmp = {
					name => $personTmp->{name},
					avatar_fid => $personTmp->{avatar_fid},
					sex => $personTmp->{sex},
				};
				
				push @studentList, $studentTmp;
				$slientCount += 1;
				if($slientCount == $topCount){
					last;
				}
			}
		}
		$leaderboard->{_id} = obj_id();
		$leaderboard->{homeworkId} = $homework->{_id};
		$leaderboard->{studentList} = \@studentList;
		
		obj_write($leaderboard);
		
	}
	
	return jr({leaderboard=>\@{$leaderboard->{studentList}}});
}

$p_leaderboard_get =<<EOF;
获取榜单

输入：
	{
		"obj":"leaderboard",
		"act":"get",
		"chapterId":""
	}
输出：
	{
		"leaderboard":[]
	}
EOF

sub p_completedChapterInfo_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "student"){
		return jr() unless assert(0, "不是学生,无法获取", "不是学生,无法获取", "不是学生,无法获取");
	}
	
	my $currentTime = time();
	my $homework = mdb()->get_collection("homework")->find_one({teacherCode=>$pref->{teacherCode}, startTime =>{'$lt'=>$currentTime}, finishTime =>{'$gt'=>$currentTime}});
	
	
	my @homeworkList = mdb()->get_collection("homework")->find({teacherCode=>$pref->{teacherCode}, booksId=>$homework->{booksId}, finishTime =>{'$lt'=>$currentTime}, publishState=>"已完成"})->sort({"publistTime"=>-1})->all();
	
	my $count = @homeworkList;
	
	if($count == 0){
		return jr() unless assert(0, "暂无课程", "暂无课程", "暂无课程");
	}
	
	return jr({homeworkList=>\@homeworkList});
}

$p_completedChapterInfo_get =<<EOF;
获取已完成章节信息

输入：
	{
		"obj":"completedChapterInfo",
		"act":"get"
	}
输入：
	{
		"homeworkList":""
	}
EOF

sub p_completedChapter_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "student"){
		return jr() unless assert(0, "不是学生,无法获取", "不是学生,无法获取", "不是学生,无法获取");
	}
	
	my $currentTime = time();
	my @homework = mdb()->get_collection("homework")->find({teacherCode=>$pref->{teacherCode}, finishTime =>{'$lt'=>$currentTime}, publishState=>"已完成"})->sort({"publistTime"=>-1})->all();
	
	my $count = @homework;
	
	if($count == 0){
		return jr() unless assert(0, "暂无课程", "暂无课程", "暂无课程");
	}
	
	return jr({homeworkList=>\@homework});
}

$p_completedChapter_get =<<EOF;
获取已完成章节

输入：
	{
		"obj":"completedChapter",
		"act":"get"
	}
输入：
	{
		"homeworkList":""
	}
EOF

#end 学生端

#begin 后台管理
sub p_personnel_add{
	return jr() unless assert($gr->{position},"position 参数少了","position","position 参数少了");
	return jr() unless assert($gr->{school},"school 参数少了","school","school 参数少了");
	return jr() unless assert($gr->{grade},"grade 参数少了","grade","grade 参数少了");
	return jr() unless assert($gr->{class},"class 参数少了","class","class 参数少了");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");
	return jr() unless assert(length($gr->{name}),"name 参数少了","name","name 参数少了");
	return jr() unless assert(length($gr->{telephoneNumber}),"telephoneNumber 参数少了","telephoneNumber","telephoneNumber 参数少了");
	
	if($gr->{position} ne "student" and $gr->{position} ne "teacher"){
		return jr() unless assert(0,"position 参数错误","position","position 参数错误");
	}
	
	my $display_name = $gr->{name};				#显示的名字,既用户名
	my $login_name = $gr->{telephoneNumber};	#登录时的账号
	my $login_passwd = "1";						#密码,由于后天管理添加,故,默认为1
	
    my $pref = account_create($gr->{server}, $display_name, "", $login_name, $gr->{login_passwd});
    
    return jr() unless assert($pref, "account creation failed");
    
    # Store other data as-is in the person record.
    obj_expand($pref, $p);

    sess_server_create($pref);
    
    # Default avatar.
    $pref->{avatar_fid} = $DEFAULT_IMAGE unless $pref->{avatar_fid};
    $pref->{name} = $display_name;
	
    $pref->{position} = $gr->{position};
	$pref->{school} = $gr->{school};
	$pref->{grade} = $gr->{grade};
    $pref->{class} = $gr->{class};
	
	if($gr->{position} eq "teacher"){
		my $class = mdb()->get_collection("classMember")->find_one({teacherCode=>$gr->{teacherCode}});
		$pref->{teacherCodeList}->{$gr->{teacherCode}} = $class->{_id};
	}else{
		$pref->{teacherCode} = $gr->{teacherCode};
	}
    
	
	obj_write($pref);

	return jr();
}

$p_personnel_add =<<EOF;
后台管理,添加学生/老师

输入：
	{
		"obj":"personnel",
		"act":"add",
		"position":"student",			职务(老师/学生)(teacher/student)
		"school":"实验中学",
		"grade":"一年级",
		"class":"二班",
		"teacherCode":"AA001001",		班级编码,例如:AA001001
		"name":"",						姓名
		"telephoneNumber":""			联系方式(为用户登录时的账号)
	}
EOF

sub p_SchoolMember_add{
	return jr() unless assert($gr->{areaId},"areaId 参数少了","areaId","areaId 参数少了");
	return jr() unless assert($gr->{school},"school 参数少了","school","school 参数少了");
	
	return jr() unless assert($gr->{name},"name 参数少了","name","name 参数少了");
	return jr() unless assert($gr->{telephone},"telephone 参数少了","telephone","telephone 参数少了");
	return jr() unless assert($gr->{sex},"sex 参数少了","sex","sex 参数少了");
	return jr() unless assert($gr->{position},"position 参数少了","position","position 参数少了");

	my $area = mdb()->get_collection("area")->find_one({_id=>$gr->{areaId}});
	if(!$area){
		return jr() unless assert(0,"所选区不存在","所选区不存在","所选区不存在");
	}
	
	my $city = mdb()->get_collection("city")->find_one({_id=>$area->{cityId}});
	if(!$city){
		return jr() unless assert(0,"所选市不存在","所选市不存在","所选市不存在");
	}
	
	my $schoolNumber = $area->{schoolNum} + 1;
	my $schoolNum = sprintf("%03d", $schoolNumber);
	my $schoolCode = $area->{areaCode}.$schoolNum;
	
	my $schoolTmp = mdb()->get_collection("SchoolMember")->find_one({school=>$gr->{school}, areaCode=>$area->{areaCode}});
	if($schoolTmp){
		return jr() unless assert(0,"学校已存在","学校已存在","学校已存在");
	}
	
	$schoolTmp = mdb()->get_collection("SchoolMember")->find_one({schoolCode=>$schoolCode});
	while($schoolTmp){
		$schoolNumber += 1;
		$schoolNum = sprintf("%03d", $schoolNumber);
		$schoolCode = $area->{areaCode}.$schoolNum;
		$schoolTmp = mdb()->get_collection("SchoolMember")->find_one({schoolCode=>$schoolCode});
	}

	#if($schoolTmp){
	#	return jr() unless assert(0,"学校编码已存在","学校编码已存在","学校编码已存在");
	#}
	
	my $personId = AddAdmin_add($schoolCode, $gr->{name}, $gr->{sex}, $gr->{position}, $gr->{telephone});
	
	my $account =mdb()->get_collection("account")->find_one({login_name => $schoolCode});

    return jr() unless assert($account, "账号创建失败", "账号创建失败", "账号创建失败");
    my $perf = obj_read("person", $account->{pids}->{default});
	
	my $currentTime = time();
	my $school = {
		_id => obj_id(),
		type => "SchoolMember",
		city => $city->{cityName},
		area => $area->{areaName},
		cityCode => $city->{cityCode},
		areaCode => $area->{areaCode},
		school => $gr->{school},
		schoolCode => $schoolCode,
		
		adminName => $gr->{name},
		sex => $gr->{sex},
		position => $gr->{position},
		telephone => $gr->{telephone},
		createTime => $currentTime,
		updateTime => $currentTime,
	};	

	obj_write($school);
	
	$area->{schoolNum} = $schoolNumber;
	obj_write($area);
	
	$perf->{schoolId} = $school->{_id};
	obj_write($perf);
	
	gradeMember_add($school->{_id});
	
	return jr();
}

$p_SchoolMember_add =<<EOF;
后台管理,添加学校成员

输入：
	{
		"obj":"SchoolMember",
		"act":"add",
		"areaId":"",
		"school":"实验中学",
		"name":"",
		"telephone":"",
		"sex":"",
		"position":""
	}
EOF

sub p_SchoolMember_delete{
	return jr() unless assert($gr->{schoolId},"schoolId 参数少了","schoolId","schoolId 参数少了");

	my $school = mdb()->get_collection("SchoolMember")->find_one({_id=>$gr->{schoolId}});
	
	if(!$school){
		return jr() unless assert(0,"学校不存在","学校不存在","学校不存在");
	}
	
	my @gradeMemberList = mdb()->get_collection("gradeMember")->find({school=>$school->{school}})->all();
	
	foreach my $item(@gradeMemberList){
		obj_delete("gradeMember", $item->{_id});
	}
	
	my @classMemberList = mdb()->get_collection("classMember")->find({school=>$school->{school}})->all();
	
	foreach my $item(@classMemberList){
		if(length($item{teacherId})){
			my $perf = obj_read("person", $item->{teacherId});
			delete ${$perf->{teacherCodeList}}{$item->{teacherCode}};
			obj_write($perf);
			#obj_delete("account", $perf->{account_id});
			#obj_delete("person", $perf->{_id});
		}
		obj_delete("classMember", $item->{_id});
	}
	
	my @personList = mdb()->get_collection("person")->find({schoolId=>$school->{_id}})->all();
	foreach my $item(@personList){
		#obj_delete("account", $item->{account_id});
		#obj_delete("person", $item->{_id});
		$item->{schoolId} = "";
		$item->{school} = "";
		$item->{gradeId} = "";
		$item->{grade} = "";
		$item->{classId} = "";
		$item->{class} = "";
		$item->{teacherCode} = "";
		obj_write($item);
	}
	
	obj_delete("SchoolMember", $school->{_id});
	return jr();
}

$p_SchoolMember_delete =<<EOF;
后台管理,删除学校成员

输入：
	{
		"obj":"SchoolMember",
		"act":"delete",
		"schoolId":""
	}
EOF

sub p_SchoolMember_modify{
	return jr() unless assert($gr->{schoolId},"schoolId 参数少了","schoolId","schoolId 参数少了");

	my $school = mdb()->get_collection("SchoolMember")->find_one({_id=>$gr->{schoolId}});
	
	if(!$school){
		return jr() unless assert(0,"学校不存在","学校不存在","学校不存在");
	}
	
	my $account = mdb()->get_collection("account")->find_one({login_name=>$school->{schoolCode}});
	my $perf = obj_read("person", $account->{pids}->{default});
	
	if($perf and length($gr->{school})){
		$school->{school} = $gr->{school};
		
		#修改学校名后,需要修改绑定年级,班级,学生,老师的school字段
		my @gradeList = mdb()->get_collection("gradeMember")->find({schoolId=>$gr->{schoolId}})->all();
		foreach my $item(@gradeList){
			$item->{school} = $gr->{school};
			obj_write($item);
		}
		
		my @classList = mdb()->get_collection("classMember")->find({schoolId=>$gr->{schoolId}})->all();
		foreach my $item(@classList){
			$item->{school} = $gr->{school};
			obj_write($item);
		}
		
		my @personList = mdb()->get_collection("person")->find({schoolId=>$gr->{schoolId}})->all();
		foreach my $item(@personList){
			$item->{school} = $gr->{school};
			obj_write($item);
		}
	}
	
	if($perf and length($gr->{telephone})){
		$perf->{telephone} = $gr->{telephone};
		$school->{telephone} = $gr->{telephone};
	}
	
	if($perf and length($gr->{sex})){
		$perf->{sex} = $gr->{sex};
		$school->{sex} = $gr->{sex};
	}
	
	if($perf and length($gr->{name})){
		$perf->{name} = $gr->{name};
		$school->{adminName} = $gr->{name};
	}
	
	if($perf and length($gr->{position})){
		$perf->{position} = $gr->{position};
		$school->{position} = $gr->{position};
	}
	
	$school->{updateTime} = time();
	
	obj_write($perf);
	obj_write($school);
	return jr();
}

$p_SchoolMember_modify =<<EOF;
后台管理,修改学校成员

输入：
	{
		"obj":"SchoolMember",
		"act":"modify",
		"schoolId":"",
		"school":"",
		"telephone":"",
		"sex":"",
		"name":"",
		"position":""
	}
EOF

sub p_SchoolMember_get{
	my %regex = ('$regex'=>"regex");
	my %data = ();
	my @conditionalKeys = keys %{$gr->{data}};
	foreach my $item (@conditionalKeys){
		if(!$gr->{data}->{$item}){
			next;
		}

		if($item eq "schoolName"){
			$regex{'$regex'} = $gr->{data}->{$item};
			$data{"school"} = \%regex;
		}
		elsif($item eq "areaId"){
			my $area = mdb()->get_collection("area")->find_one({_id=>$gr->{data}->{$item}});
			if(!$area){
				return jr() unless assert(0,"所选区不存在","所选区不存在","所选区不存在");
			}
			$data{"area"} = $area->{areaName};
		}
		else{
			$data{$item} = $gr->{data}->{$item};
		}
	}
	
	my @schoolList = mdb()->get_collection("SchoolMember")->find(\%data)->sort({"createTime"=>-1})->all();
	
	foreach my $item(@schoolList){
		my @studentList = mdb()->get_collection("person")->find({schoolId=>$item->{_id}, position=>"student"})->all();
		my $count = @studentList;
		$item->{studentCount} = $count;
	}
	
	return jr({schoolList=>\@schoolList});
}

$p_SchoolMember_get =<<EOF;
根据地区获取学校成员

输入：
	{
		"obj":"SchoolMember",
		"act":"get",
		"data":{
			"schoolName":"",
			"areaId":""
		}
	}
输出：
	{
		"schoolList":[
			"studentCount":123,
		]
	}
EOF

#{
#	"obj":"SchoolMember",
#	"act":"add",
#	"city":"福州市",
#	"area":"鼓楼区",
#	"school":"实验中学",
#	"grade":"一年级",
#	"class":"二班",
#	"teacherCode":"AA001001"		班级编码,例如:AA001001
#}

sub gradeMember_add{
	#return jr() unless assert($gr->{schoolId},"schoolId 参数少了","schoolId","schoolId 参数少了");
	#return jr() unless assert($gr->{grade},"grade 参数少了","grade","grade 参数少了");

	
	#添加学校之后,直接添加六个年级
	my @gradeList = ("一年级", "二年级", "三年级", "四年级", "五年级", "六年级");
	
	my $schoolId = $_[0];
	my $school = mdb()->get_collection("SchoolMember")->find_one({_id=>$schoolId});
	if(!$school){
		return jr() unless assert(0,"所选学校不存在","所选学校不存在","所选学校不存在");
	}
	
	foreach my $item(@gradeList){
		my $gradeItem = mdb()->get_collection("gradeMember")->find_one({schoolId=>$schoolId, grade=>$item});
		if($gradeItem){
			#return jr() unless assert(0,"该年级已经存在","该年级已经存在","该年级已经存在");
			next;
		}
		
		my $gradeCode = $school->{schoolCode};
		my $currentTime = time();
		my $grade = {
			_id => obj_id(),
			type => "gradeMember",
			city => $school->{city},
			area => $school->{area},
			school => $school->{school},
			grade => $item,
			gradeCode => $gradeCode,
			schoolId => $school->{_id},
			createTime => $currentTime,
			updateTime => $currentTime,
		};	
	
		obj_write($grade);
	}
	return jr();
}

#$p_gradeMember_add =<<EOF;
#添加年级成员
#
#输入：
#	{
#		"obj":"gradeMember",
#		"act":"add",
#		"schoolId":"",
#		"grade":"一年级"
#	}
#EOF

sub p_gradeMember_get{
	return jr() unless assert($gr->{schoolId},"schoolId 参数少了","schoolId","schoolId 参数少了");

	my $school = mdb()->get_collection("SchoolMember")->find_one({_id=>$gr->{schoolId}});
	if(!$school){
		return jr() unless assert(0,"所选学校不存在","所选学校不存在","所选学校不存在");
	}
	
	my @gradeList = mdb()->get_collection("gradeMember")->find({schoolId=>$gr->{schoolId}})->all();

	return jr({gradeList=>\@gradeList});
}

$p_gradeMember_get =<<EOF;
获取年级成员

输入：
	{
		"obj":"gradeMember",
		"act":"get",
		"schoolId":""
	}
输出：
	{
		"gradeList":[]
	}
EOF

sub p_classMember_add{
	return jr() unless assert($gr->{gradeId},"gradeId 参数少了","gradeId","gradeId 参数少了");
	return jr() unless assert($gr->{class},"class 参数少了","class","class 参数少了");
	#return jr() unless assert($gr->{classCode},"classCode 参数少了","classCode","classCode 参数少了");

	my $grade = mdb()->get_collection("gradeMember")->find_one({_id=>$gr->{gradeId}});
	if(!$grade){
		return jr() unless assert(0,"所选年级不存在","所选年级不存在","所选年级不存在");
	}
	
	my $classItem = mdb()->get_collection("classMember")->find_one({class=>$gr->{class}, gradeId=>$gr->{gradeId}});
	if($classItem){
		return jr() unless assert(0,"班级已存在","班级已存在","班级已存在");
	}
	
	my $classCode = "";
	
	if($gr->{classCode}){
		$classCode = $grade->{gradeCode}.$gr->{classCode};
		my $classTmp = mdb()->get_collection("classMember")->find_one({teacherCode=>$classCode});
		if($classTmp){
			return jr() unless assert(0,"班级编码已存在","班级编码已存在","班级编码已存在");
		}
		
		my $classT = mdb()->get_collection("classMember")->find_one({class=>$gr->{class}, gradeId=>$grade->{_id}});
		if($classT){
			return jr() unless assert(0,"班级名称已存在","班级名称已存在","班级名称已存在");
		}
	}else{
		while(true){
			my $count = int(rand(1000));
			my $num=sprintf("%03d", $count);
			$classCode = $grade->{gradeCode}.$num;
			
			my $classTmp = mdb()->get_collection("classMember")->find_one({teacherCode=>$classCode});
			if(!$classTmp){
				last;
			}
		}
	}
	my $currentTime = time();
	my $class = {
		_id => obj_id(),
		type => "classMember",
		city => $grade->{city},
		area => $grade->{area},
		school => $grade->{school},
		grade => $grade->{grade},
		class => $gr->{class},
		teacherCode => $classCode,
		gradeId => $grade->{_id},
		schoolId => $grade->{schoolId},
		createTime => $currentTime,
		updateTime => $currentTime,
	};	

	obj_write($class);
	return jr();
}

$p_classMember_add =<<EOF;
后台管理,添加班级成员

输入：
	{
		"obj":"classMember",
		"act":"add",
		"gradeId":"",
		"class":"三班",
		"classCode":""			默认不传,没有的时候,随机生成。
	}
EOF

sub p_classMember_delete{
	return jr() unless assert($gr->{classId},"classId 参数少了","classId","classId 参数少了");

	my $class = mdb()->get_collection("classMember")->find_one({_id=>$gr->{classId}});
	if(!$class){
		return jr() unless assert(0,"所选年级不存在","所选年级不存在","所选年级不存在");
	}
	
	if(length($class{teacherId})){
		my $perf = obj_read("person", $class->{teacherId});
		delete ${$perf->{teacherCodeList}}{$class->{teacherCode}};
		obj_write($perf);
	}
	
	my @personList = mdb()->get_collection("person")->find({classId=>$class->{_id}, position=>"student"});
	foreach my $item(@personList){
		$item->{class} = "";
		$item->{teacherCode} = "";
		$item->{classId} = "";
		obj_write($item);
	}
	
	#删除作业
	my @homeworkList = mdb()->get_collection("homework")->find({teacherCode=>$class->{teacherCode}})->all();
	foreach my $item(@homeworkList){
		obj_delete("homework", $item->{_id});
	}
	my @booksHomeworkInfoList = mdb()->get_collection("booksHomeworkInfo")->find({teacherCode=>$class->{teacherCode}})->all();
	foreach my $item(@booksHomeworkInfoList){
		obj_delete("booksHomeworkInfo", $item->{_id});
	}
	
	my @homeworkShareList = mdb()->get_collection("homeworkShare")->find({teacherCode=>$class->{teacherCode}})->all();
	foreach my $item(@booksHomeworkInfoList){
		obj_delete("homeworkShare", $item->{_id});
	}
	
	obj_delete("classMember", $class->{_id});
	
	return jr();
}

$p_classMember_delete =<<EOF;
后台管理,删除班级成员

输入：
	{
		"obj":"classMember",
		"act":"delete",
		"classId":""
	}
EOF

sub p_classMember_modify{
	return jr() unless assert($gr->{classId},"classId 参数少了","classId","classId 参数少了");
	#return jr() unless assert($gr->{className},"className 参数少了","className","className 参数少了");

	my $class = mdb()->get_collection("classMember")->find_one({_id=>$gr->{classId}});
	if(!$class){
		return jr() unless assert(0,"所选班级不存在","所选班级不存在","所选班级不存在");
	}
	
	if(length($gr->{class})){
		$class->{class} = $gr->{class};
		
		#修改班级名后,需要修改绑定学生,老师的class字段
		my @personList = mdb()->get_collection("person")->find({teacherCode=>$class->{teacherCode}})->all();
		foreach my $item(@personList){
			$item->{class} = $gr->{class};
			obj_write($item);
		}
	}
	
	if(length($gr->{gradeId})){
		my $grade = mdb()->get_collection("gradeMember")->find_one({_id=>$gr->{gradeId}});
		if(!$grade){
			return jr() unless assert(0,"所选年级不存在","所选年级不存在","所选年级不存在");
		}
		
		$class->{grade} = $grade->{grade};
		$class->{school} = $grade->{school};
		$class->{gradeId} = $grade->{_id};
		$class->{schoolId} = $grade->{schoolId};
	}
	
	$class->{updateTime} = time();
	obj_write($class);
	
	return jr();
}

$p_classMember_modify =<<EOF;
后台管理,修改班级成员

输入：
	{
		"obj":"classMember",
		"act":"modify",
		"classId":"",
		"class":"",
		"gradeId":""
	}
EOF

sub p_classMember_get{
	#return jr() unless assert($gr->{gradeId},"gradeId 参数少了","gradeId","gradeId 参数少了");
	#return jr() unless assert($gr->{classCode},"classCode 参数少了","classCode","classCode 参数少了");

	if(!length($gr->{gradeId}) and !length($gr->{schoolId})){
		return jr() unless assert($gr->{gradeId},"缺少参数","缺少参数","缺少参数");
	}
	
	my @classList = ();
	
	if(length($gr->{gradeId})){
		my $grade = mdb()->get_collection("gradeMember")->find_one({_id=>$gr->{gradeId}});
		if(!$grade){
			return jr() unless assert(0,"所选年级不存在","所选年级不存在","所选年级不存在");
		}
		
		#@classList = mdb()->get_collection("classMember")->find({gradeId=>$gr->{gradeId}})->all();
		
		@classListTmp = mdb()->get_collection("classMember")->find({gradeId=>$gr->{gradeId}})->all();
		@classList = sort {$a->{class} <=> $b->{class}} @classListTmp;
	}elsif(length($gr->{schoolId})){
		my $school = mdb()->get_collection("SchoolMember")->find_one({_id=>$gr->{schoolId}});
		if(!$school){
			return jr() unless assert(0,"所选学校不存在","所选学校不存在","所选学校不存在");
		}
		
		#@classList = mdb()->get_collection("classMember")->find({schoolId=>$gr->{schoolId}})->all();
		
		my @gradeList = mdb()->get_collection("gradeMember")->find({schoolId=>$gr->{schoolId}})->all();
		
		#return jr({aaa=>\@classList});
		my @gradeListTmp = sort {$a->{grade} <=> $b->{grade}} @gradeList;
		foreach my $item(@gradeListTmp){
			my @classListTmp = mdb()->get_collection("classMember")->find({gradeId=>$item->{_id}})->all();
			
			my @classListT = sort {$a->{class} <=> $b->{class}} @classListTmp;
			
			my $count = @classList;
			splice(@classList, $count, 0, @classListT); 
		}
	}
	
	foreach my $item(@classList){
		my @personList = mdb()->get_collection("person")->find({teacherCode=>$item->{teacherCode}})->all();
		my $count = @personList;
		$item->{studentCount} = $count;
		if(length($item->{teacherId})){
			my $person = obj_read("person", $item->{teacherId});
			if($person){
				$item->{teacherName} = $person->{name};
			}
		}
	}
	
	return jr({classList=>\@classList});
}

$p_classMember_get =<<EOF;
后台管理,获取班级成员

输入：
	{
		"obj":"classMember",
		"act":"get",
		"gradeId":"o15385843173846189975",
		"schoolId":""
	}
输出：
	{
		"classList":[]
	}
EOF

sub p_teacherList_get{
	my %regex = ('$regex'=>"regex");
	my %data = ();
	my @conditionalKeys = keys %{$gr->{data}};
	foreach my $item (@conditionalKeys){
		if(!$gr->{data}->{$item}){
			next;
		}
		elsif($item eq "teacherCode"){
			next;
		}
		
		if($item eq "teacherName"){
			$regex{'$regex'} = $gr->{data}->{$item};
			$data{"name"} = \%regex;
		}
		elsif($item eq "telephone_Number"){
			$data{"login_name"} = $gr->{data}->{$item};
		}
		else{
			$data{$item} = $gr->{data}->{$item};
		}
	}

	$data{position} = "teacher";
	
	my @personList = mdb()->get_collection("person")->find(\%data)->all();

	my @personListTmp = ();
	if($gr->{data}->{teacherCode}){
		foreach my $item (@personList){
			my @teacherCodeList = keys %{$item->{teacherCodeList}};
			if(exists(${$item->{teacherCodeList}}{$gr->{data}->{teacherCode}})){
				push @personListTmp, $item;
			}
		}
	}
	else{
		@personListTmp = @personList;
	}

	foreach $item (@personListTmp){
		my @classIdList = values %{$item->{teacherCodeList}};
		my @classNameList = ();
		foreach my $classItem(@classIdList){
			my $class = mdb()->get_collection("classMember")->find_one({_id=>$classItem});
			if($class){
				push @classNameList, $class->{grade}.$class->{class};
			}
		}
		$item->{classIdList} = \@classIdList;
		$item->{classNameList} = \@classNameList;
	}
	
	return jr({personList=>\@personListTmp});
}

$p_teacherList_get =<<EOF;
后台管理,获取教师列表

输入：
	{
		"obj":"teacherList",
		"act":"get",
		"data":
		{
			"teacherName":"",
			"sex":"",
			"telephone_Number":"4",
			"teacherCode":"",
			"schoolId":""
		}
	}
输出：
	{
		"personList":[]
	}
EOF

sub p_studentList_get{
	my $limit = $gr->{limit};
	$limit = 10 unless $limit;
	
	my $page = $gr->{page};
	$page = 1 unless $page;
	my $skipCount = ($page - 1) * $limit;
	
	#sort 以index字段排序,1为升序,-1为降序
	#limit 读取的记录条数
	#skip 跳过的记录条数
	
	my %regex = ('$regex'=>"regex");
	my %data = ();
	my @conditionalKeys = keys %{$gr->{data}};
	foreach my $item (@conditionalKeys){
		if(!$gr->{data}->{$item}){
			next;
		}
		
		if($item eq "classId"){
			next;
		}
		
		if($item eq "name"){
			$regex{'$regex'} = $gr->{data}->{$item};
			$data{$item} = \%regex;
		}
		elsif($item eq "telephone_Number"){
			$data{"login_name"} = $gr->{data}->{$item};
		}
		else{
			$data{$item} = $gr->{data}->{$item};
		}
	}

	$data{position} = "student";
	
	my @personListTmp = mdb()->get_collection("person")->find(\%data)->all();
	my $total = @personListTmp;
	
	my @personList = mdb()->get_collection("person")->find(\%data)->limit($limit)->skip($skipCount)->all();

	return jr({total=>$total, personList=>\@personList});
}

$p_studentList_get =<<EOF;
后台管理,获取学生列表

输入：
	{
		"obj":"studentList",
		"act":"get",
		"data":
		{
			"name":"",
			"sex":"",
			"telephone_Number":"4",
			"teacherCode":"",
			"gradeId"":"",
			"schoolId":""
		},
		"page":1,				(默认为1,既,第一页)
		"limit":10,				(默认为10,既,每次请求十条数据)
	}
输出：
	{
		"total":12,
		"personList":[]
	}
EOF

sub p_teacherCode_add{
	return jr() unless assert($gr->{teacherId},"teacherId 参数少了","teacherId","teacherId 参数少了");
	return jr() unless assert($gr->{classId},"classId 参数少了","classId","classId 参数少了");

	my $pref = obj_read("person", $gr->{teacherId});
	if(!$pref){
		return jr() unless assert(0,"教师不存在","教师不存在","教师不存在");
	}
	
	my $class = mdb()->get_collection("classMember")->find_one({_id=>$gr->{classId}});
	
	if(!$class){
		return jr() unless assert(0,"班级不存在","班级不存在","班级不存在");
	}
	
	$pref->{teacherCodeList}{$class->{teacherCode}} = $class->{_id};
	
	obj_write($pref);
	
	$class->{teacherId} = $pref->{_id};
	obj_write($class);
	return jr();
}

$p_teacherCode_add =<<EOF;
添加教师管理的班级

输入：
	{
		"obj":"teacherCode",
		"act":"add",
		"classId":"",
		"teacherId":""
	}
EOF

sub p_teacherCode_modify{
	return jr() unless assert($gr->{teacherId},"teacherId 参数少了","teacherId","teacherId 参数少了");
	return jr() unless assert($gr->{teacherCodeOld},"teacherCodeOld 参数少了","teacherCodeOld","teacherCodeOld 参数少了");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");

	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0,"教师不存在","教师不存在","教师不存在");
	}
	
	if(!exists($pref->{teacherCodeList}{$gr->{teacherCodeOld}})){
		return jr() unless assert(0,"旧教师号不存在","旧教师号不存在","旧教师号不存在");
	}
	
	delete $pref->{teacherCodeList}{$gr->{teacherCodeOld}};
	
	my $class = mdb()->get_collection("classMember")->find_one({teacherCode=>$gr->{teacherCode}});
	
	if(!$class){
		return jr() unless assert(0,"新教师号不存在","新教师号不存在","新教师号不存在");
	}
	
	$pref->{teacherCodeList}{$gr->{teacherCode}} = $class->{_id};
	
	obj_write($pref);
	return jr();
}

$p_teacherCode_modify =<<EOF;
修改教师管理的班级

输入：
	{
		"obj":"teacherCode",
		"act":"modify",
		"teacherCodeOld":"AA001001"		班级编码,例如:AA001001
		"teacherCode":"AA001001"		班级编码,例如:AA001001
		"teacherId":""
	}
EOF

sub p_AdminManageTeacher_add{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{classIdList},"classIdList 参数少了","classIdList","classIdList 参数少了");
	return jr() unless assert($gr->{name},"name 参数少了","name","name 参数少了");
	return jr() unless assert($gr->{sex},"sex 参数少了","sex","sex 参数少了");
	return jr() unless assert($gr->{telephone},"telephone 参数少了","telephone","telephone 参数少了");
	return jr() unless assert($gr->{email},"email 参数少了","email","email 参数少了");

	my $admin = obj_read("person", $gs->{pid});
	if(!$admin){
		return jr() unless assert(0,"未登录","未登录","未登录");
	}
	
	my $person = mdb()->get_collection("person")->find_one({login_name=>$gr->{telephone}});
	
	if($person){
		return jr() unless assert(0,"账号已存在","账号已存在","账号已存在");
	}
	
	my @visibleClassList = ();
	foreach my $item(@{$gr->{classIdList}}){
		my $class = mdb()->get_collection("classMember")->find_one({_id=>$item});
	
		if($class and length($class->{teacherId})){
			push @visibleClassList, $class;
		}
	}
	
	if(scalar(@visibleClassList)){
		my $message = "以下班级已有教师";
		my $index = 0;
		foreach my $item (@visibleClassList){
			if($index == 0){
				$message = $message.$item->{grade}.$item->{class};
				$index += 1;
			}else{
				$message = $message.",".$item->{grade}.$item->{class}
			}
		}
		return jr() unless assert(0,$message,$message,$message);
	}
	
	my $res = adminAddPerson_add($gr->{telephone}, "teacher");
	
	if(!length($res->{personId})){
		return jr() unless assert(0,"创建用户失败","创建用户失败","创建用户失败");
	}
	
	my $perf = obj_read("person", $res->{personId});
	
	foreach my $item(@{$gr->{classIdList}}){
		my $class = mdb()->get_collection("classMember")->find_one({_id=>$item});
	
		if($class){
			#return jr() unless assert(0,"班级不存在","班级不存在","班级不存在");
			$perf->{teacherCodeList}{$class->{teacherCode}} = $class->{_id};
			$class->{teacherId} = $perf->{_id};
			obj_write($class);
		}
	}
	
	$perf->{name} = $gr->{name};
	$perf->{sex} = $gr->{sex};
	$perf->{email} = $gr->{email};
	$perf->{schoolId} = $gr->{schoolId};
	$perf->{permission} = "user";
	obj_write($perf);
	
	return jr();
}

$p_AdminManageTeacher_add =<<EOF;
添加教师

输入：
	{
		"obj":"AdminManageTeacher",
		"act":"add",
		"classIdList":[
			"",
			""
		],
		"name":"",
		"sex":"",
		"telephone":"",
		"email":"",
		"schoolId":""
	}
EOF

sub p_AdminManageTeacher_modify{
	return jr() unless assert($gr->{classIdList},"classIdList 参数少了","classIdList","classIdList 参数少了");
	return jr() unless assert($gr->{name},"name 参数少了","name","name 参数少了");
	return jr() unless assert($gr->{sex},"sex 参数少了","sex","sex 参数少了");
	return jr() unless assert($gr->{telephone},"telephone 参数少了","telephone","telephone 参数少了");
	return jr() unless assert($gr->{email},"email 参数少了","email","email 参数少了");

	my $perf = obj_read("person", $gr->{teahcerId});
	
	my @classIdListTmp = values %{$perf->{teacherCodeList}};
	foreach my $classItem(@classIdListTmp){
		my $class = mdb()->get_collection("classMember")->find_one({_id=>$classItem});
		if($class){
			$class->{teacherId} = "";
			obj_write($class);
		}
	}
	delete $perf->{teacherCodeList};
	
	my @visibleClassList = ();
	foreach my $item(@{$gr->{classIdList}}){
		my $class = mdb()->get_collection("classMember")->find_one({_id=>$item});
	
		if($class and length($class->{teacherId})){
			push @visibleClassList, $class;
		}
	}
	
	if(scalar(@visibleClassList)){
		my $message = "以下班级已有教师";
		my $index = 0;
		foreach my $item (@visibleClassList){
			if($index == 0){
				$message = $message.$item->{grade}.$item->{class};
				$index += 1;
			}else{
				$message = $message.",".$item->{grade}.$item->{class}
			}
		}
		return jr() unless assert(0,$message,$message,$message);
	}
	
	foreach my $item(@{$gr->{classIdList}}){
		my $class = mdb()->get_collection("classMember")->find_one({_id=>$item});
	
		if($class){
			$perf->{teacherCodeList}{$class->{teacherCode}} = $class->{_id};
			$class->{teacherId} = $perf->{_id};
			obj_write($class);
		}
	}

	$perf->{name} = $gr->{name};
	$perf->{sex} = $gr->{sex};
	$perf->{email} = $gr->{email};
	obj_write($perf);
	return jr();
}

$p_AdminManageTeacher_modify =<<EOF;
修改教师信息

输入：
	{
		"obj":"AdminManageTeacher",
		"act":"modify",
		"classIdList":"",
		"name":"",
		"sex":"",
		"telephone":"",
		"email":"",
		"teahcerId":""
	}
EOF

sub p_AdminManageTeacher_delete{
	return jr() unless assert($gr->{teahcerId},"teahcerId 参数少了","teahcerId","teahcerId 参数少了");

	my $perf = obj_read("person", $gr->{teahcerId});
	
	my @classIdList = values %{$perf->{teacherCodeList}};
	foreach my $item(@classIdList){
		my $class = mdb()->get_collection("classMember")->find_one({_id=>$item});
		if($class){
			$class->{teacherId} = "";
			obj_write($class);
		}
	}
	
	obj_delete("account", $perf->{account_id});
	obj_delete("person", $perf->{_id});
	return jr();
}

$p_AdminManageTeacher_delete =<<EOF;
删除教师

输入：
	{
		"obj":"AdminManageTeacher",
		"act":"delete",
		"teahcerId":""
	}
EOF

sub p_AdminManagePasswd_reste{
	return jr() unless assert($gr->{schoolId},"schoolId 参数少了","schoolId","schoolId 参数少了");
	
	my $school = mdb()->get_collection("SchoolMember")->find_one({_id=>$gr->{schoolId}});
	
	my $account = mdb()->get_collection("account")->find_one({login_name => $school->{schoolCode}});

	if(!$account){
		return jr() unless assert(0, "用户不存在","FAILED","用户不存在");
	}
	
	$ret = account_reset_passwd($account->{_id}, "123456");
	
	if($ret == 0){
		return jr() unless assert(0, "修改密码失败","FAILED","修改密码失败");
	}
	return jr();
}

$p_AdminManagePasswd_reste =<<EOF;
管理员重置学校管理员账号密码,密码为123456

输入：
	{
		"obj":"AdminManagePasswd",
		"act":"reste",
		"schoolId":""
	}
EOF

#111111111111111111111111

sub p_AdminManageStudent_add{
	return jr() unless assert($gr->{classId},"classId 参数少了","classId","classId 参数少了");
	return jr() unless assert($gr->{name},"name 参数少了","name","name 参数少了");
	return jr() unless assert($gr->{sex},"sex 参数少了","sex","sex 参数少了");
	return jr() unless assert($gr->{telephone},"telephone 参数少了","telephone","telephone 参数少了");

	my $class = mdb()->get_collection("classMember")->find_one({_id=>$gr->{classId}});
	
	if(!$class){
		return jr() unless assert(0,"班级不存在","班级不存在","班级不存在");
	}
	
	my $person = mdb()->get_collection("person")->find_one({login_name=>$gr->{telephone}});
	
	if($person){
		return jr() unless assert(0,"用户已存在","用户已存在","用户已存在");
	}
	
	my $res = adminAddPerson_add($gr->{telephone}, "student");
	
	if(!length($res->{personId})){
		return jr() unless assert(0,"创建用户失败","创建用户失败","创建用户失败");
	}
	
	my $perf = obj_read("person", $res->{personId});
	
	$perf->{school} = $class->{school};
	$perf->{grade} = $class->{grade};
	$perf->{class} = $class->{class};
	$perf->{schoolId} = $class->{schoolId};
	$perf->{gradeId} = $class->{gradeId};
	$perf->{classId} = $class->{_id};

	$perf->{teacherCode} = $class->{teacherCode};
	$perf->{name} = $gr->{name};
	$perf->{sex} = $gr->{sex};
	obj_write($perf);
	
	#如果班级已有分组,需要将添加的学生添加进未分组学生中
	my $group = mdb()->get_collection("classGroup")->find_one({teacherCode=>$class->{teacherCode}});
	if($group){
		my $student = {
			studentId => $perf->{_id},
			studentName => $perf->{name},
			avatar_fid => $perf->{avatar_fid},
		};
		${$group->{otherList}}{$student->{studentId}} = $student;
		obj_write($group);
	}
	
	return jr();
}

$p_AdminManageStudent_add =<<EOF;
添加学生

输入：
	{
		"obj":"AdminManageStudent",
		"act":"add",
		"classId":"",
		"name":"",
		"sex":"",
		"telephone":"",
	}
EOF

sub p_AdminManageStudent_modify{
	return jr() unless assert($gr->{classId},"classId 参数少了","classId","classId 参数少了");
	return jr() unless assert($gr->{name},"name 参数少了","name","name 参数少了");
	return jr() unless assert($gr->{sex},"sex 参数少了","sex","sex 参数少了");
	return jr() unless assert($gr->{studentId},"studentId 参数少了","studentId","studentId 参数少了");

	my $class = mdb()->get_collection("classMember")->find_one({_id=>$gr->{classId}});
	
	if(!$class){
		return jr() unless assert(0,"班级不存在","班级不存在","班级不存在");
	}
	
	my $perf = obj_read("person", $gr->{studentId});
	
	AdminManageStudent_update($perf, "delete");
	
	$perf->{teacherCode} = $class->{teacherCode};
	$perf->{name} = $gr->{name};
	$perf->{sex} = $gr->{sex};
	
	$perf->{school} = $class->{school};
	$perf->{grade} = $class->{grade};
	$perf->{class} = $class->{class};
	$perf->{schoolId} = $class->{schoolId};
	$perf->{gradeId} = $class->{gradeId};
	$perf->{classId} = $class->{_id};
	$perf->{permission} = "user";
	
	AdminManageStudent_update($perf, "add");
	obj_write($perf);
	return jr();
}

$p_AdminManageStudent_modify =<<EOF;
修改学生信息

输入：
	{
		"obj":"AdminManageStudent",
		"act":"modify",
		"classId":"",
		"name":"",
		"sex":"",
		"telephone":"",
		"studentId":""
	}
EOF

sub p_AdminManageStudent_delete{
	return jr() unless assert($gr->{studentIdList},"studentIdList 参数少了","studentIdList","studentIdList 参数少了");
	foreach my $item (@{$gr->{studentIdList}}){
		my $perf = obj_read("person", $item);
		
		AdminManageStudent_update($perf, "delete");
		
		obj_delete("account", $perf->{account_id});
		obj_delete("person", $perf->{_id});
	}
	return jr();
}

$p_AdminManageStudent_delete =<<EOF;
删除学生

输入：
	{
		"obj":"AdminManageStudent",
		"act":"delete",
		"studentIdList":[]
	}
EOF

sub AdminManageStudent_update{
	my $perf = $_[0];
	my $type = $_[1];
	
	my $group = mdb()->get_collection("classGroup")->find_one({teacherCode=>$perf->{teacherCode}});
	
	if(!$group){
		return jr();# unless assert(0,"分组不存在","分组不存在","分组不存在");
	}
	
	if($type eq "delete"){
		my @groupNameList = keys %{$group->{groupList}};
		my $flag = 0;
		foreach my $groupItem(@groupNameList){
			my @studentList = keys %{$group->{groupList}{$groupItem}{studentList}};
			if(exists($group->{groupList}{$groupItem}{studentList}{$perf->{_id}})){
				#存在
				delete ${${$group->{groupList}}{$groupItem}->{studentList}}{$perf->{_id}};
				$flag = 1;
				last;
			}
		}
		
		if($flag == 0){
			if(exists($group->{otherList}{$perf->{_id}})){
				delete ${$group->{otherList}}{$perf->{_id}};
			}
		}
	}elsif($type eq "add"){
		if(!exists($group->{otherList}{$perf->{_id}})){
			my $student = {
				studentId => $perf->{_id},
				studentName => $perf->{name},
				avatar_fid => $perf->{avatar_fid},
			};
			${$group->{otherList}}{$student->{studentId}} = $student;
		}
	}
	
	obj_write($group);
	
	return jr();
}

#$AdminManageStudent_update =<<EOF;
#改动学生后,更新数据。

sub p_AdminManageStudentPasswd_reste{
	return jr() unless assert($gr->{teahcerId},"teahcerId 参数少了","teahcerId","teahcerId 参数少了");

	my $account = mdb()->get_collection("account")->find_one({login_name => $gr->{telephone}});

	if(!$account){
		return jr() unless assert(0, "用户不存在","FAILED","用户不存在");
	}
	
	$ret = account_reset_passwd($account->{_id}, "123456");
	
	if($ret == 0){
		return jr() unless assert(0, "修改密码失败","FAILED","修改密码失败");
	}
	return jr();
}

$p_AdminManageStudentPassword_reste =<<EOF;
重置学生账号密码

输入：
	{
		"obj":"AdminManageStudentPassword",
		"act":"reste",
		"telephone":""
	}
EOF

sub p_personPassword_reste{
	return jr() unless assert($gr->{personId},"personId 参数少了","personId","personId 参数少了");

	my $perf = obj_read("person", $gr->{personId});
	if(!$perf){
		return jr() unless assert(0, "用户不存在","FAILED","用户不存在");
	}
	
	my $account = mdb()->get_collection("account")->find_one({_id => $perf->{account_id}});
	if(!$account){
		return jr() unless assert(0, "用户不存在","FAILED","用户不存在");
	}
	
	$ret = account_reset_passwd($account->{_id}, "123456");
	
	if($ret == 0){
		return jr() unless assert(0, "修改密码失败","FAILED","修改密码失败");
	}
	return jr();
}

$p_personPassword_reste =<<EOF;
重置账号密码,修改为123456

输入：
	{
		"obj":"personPassword",
		"act":"reste",
		"personId":""
	}
EOF

#sub importStudent_add{
#	return jr() unless assert($gr->{studentList},"studentList 参数少了","studentList","studentList 参数少了");
#	
#	foreach my $item(@{$gr->{studentList}}){
#		my $class = mdb()->get_collection("classMember")->find_one({teacherCode=>$item->{teacherCode}});
#		if(!$class){
#			#return jr() unless assert(0,"班级不存在","班级不存在","班级不存在");
#			next;
#		}
#		
#		my $person = mdb()->get_collection("person")->find_one({login_name=>$item->{telephone}});
#		if($person){
#			#return jr() unless assert(0,"用户已存在","用户已存在","用户已存在");
#			next;
#		}
#		
#		my $res = adminAddPerson_add($item->{telephone}, "student");
#		if(!length($res->{personId})){
#			#return jr() unless assert(0,"创建用户失败","创建用户失败","创建用户失败");
#			next;
#		}
#		
#		my $perf = obj_read("person", $res->{personId});
#		$perf->{school} = $class->{school};
#		$perf->{grade} = $class->{grade};
#		$perf->{class} = $class->{class};
#		$perf->{schoolId} = $class->{schoolId};
#		$perf->{gradeId} = $class->{gradeId};
#		$perf->{classId} = $class->{_id};
#		$perf->{teacherCode} = $class->{teacherCode};
#		$perf->{name} = $item->{name};
#		$perf->{sex} = $item->{sex};
#		obj_write($perf);
#	}
#	return jr();
#}

sub importStudent_add{
	my $teacherCode = $_[0];
	my $name = $_[1];
	my $sex = $_[2];
	my $telephone = $_[3];
	
	my $class = mdb()->get_collection("classMember")->find_one({teacherCode=>$teacherCode});
	if(!$class){
		#return jr() unless assert(0,"班级不存在","班级不存在","班级不存在");
		next;
	}
	
	my $person = mdb()->get_collection("person")->find_one({login_name=>$telephone});
	if($person){
		#return jr() unless assert(0,"用户已存在","用户已存在","用户已存在");
		next;
	}
	
	my $res = adminAddPerson_add($telephone, "student");
	if(!length($res->{personId})){
		#return jr() unless assert(0,"创建用户失败","创建用户失败","创建用户失败");
		next;
	}
	
	my $perf = obj_read("person", $res->{personId});
	$perf->{school} = $class->{school};
	$perf->{grade} = $class->{grade};
	$perf->{class} = $class->{class};
	$perf->{schoolId} = $class->{schoolId};
	$perf->{gradeId} = $class->{gradeId};
	$perf->{classId} = $class->{_id};
	$perf->{teacherCode} = $class->{teacherCode};
	$perf->{name} = $name;
	$perf->{sex} = $sex;
	obj_write($perf);
	
	return jr();
}

#$importStudent_add =<<EOF;
#导入学生添加
#输入：
#	{
#		"obj":"importStudent",
#		"act":"add",
#		"studentList":[
#			"classId":"",
#			"name":"",
#			"sex":"",
#			"telephone":""
#		]
#	}
#EOF

sub p_student_import{
	return jr() unless assert($gr->{fid},"fid 参数少了","fid","fid 参数少了");
	
	my $filePathFid = "/var/www/games/files/yqds/".$gr->{fid};
	
	my @rows;
	my $csv = Text::CSV_XS->new({});
	open my $fh, "<:encoding(gbk)", "$filePathFid" or die "song.csv: $!";
	
	my @userList = ();
	my $index = 0;
	my $aa = "";
	while ( my $row = $csv->getline($fh) ) {
		#教师号,姓名,性别,手机号
		if($index != 0){
			#$aa = $aa.@$row[0]."--".@$row[1]."--".@$row[2]."--".@$row[3]."\r\n";
			importStudent_add(@$row[0], @$row[1], @$row[2], @$row[3]);
		}
		else{
			$index += 1;
		}
	}
	
	$csv->eof or $csv->error_diag();
	close $fh;
	return jr();
}

$p_student_import =<<EOF;
批量导入学生
输入：
	{
		"obj":"student",
		"act":"import",
		"fid":""
	}
EOF

#222222222222222222222222

#sub p_studentRoster_add{
#	return jr() unless assert($gr->{fileFid},"fileFid 参数少了","fileFid","fileFid 参数少了");
#	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");
#
#	#csv  姓名   电话
#	$DOWNLOAD_ROOT = "/var/www/games/files/yqds/";
#	my $file = $DOWNLOAD_ROOT.$gr->{fileFid};;
#	#my $csv = Text::CSV_XS->new ({
#	#    binary => 1,
#	#    auto_diag => 1,
#	#    sep_char => ',' # not really needed as this is the default
#	#});
#	my $csv = Text::CSV_XS->new ();
#	$csv->eol(undef);
#	my $sum = 0;
#	open(my $data, '<:encoding(gbk)', $file) or die "Could not open '$file' $!\n";
#	
#	my $index = 1;
#	while (my $fields = $csv->getline( $data )) {
#		my $studentRoster = {
#			_id => obj_id(),
#			type => "studentRoster",
#			teacherCode => $gr->{teacherCode},
#			studentName => $fields->[0],
#			phoneNum => $fields->[1],
#			studentNum => $gr->{teacherCode}.$index,
#		};	
#	
#		obj_write($studentRoster);
#		$index += 1;
#	}
#	#if (not $csv->eof) {
#	#    $csv->error_diag();
#	#}
#	close $data;
#
#	return jr();
#}

#$p_studentRoster_add =<<EOF;
#后台管理,添加学生名单
#
#输入：
#	{
#		"obj":"studentRoster",
#		"act":"add",
#		"fileFid":"f15380548459978458881001",
#		"teacherCode":"AA001001"		班级编码,例如:AA001001
#	}
#EOF

sub p_studentRoster_add{
	return jr() unless assert($gr->{studentName},"studentName 参数少了","studentName","studentName 参数少了");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");

	my $class = mdb()->get_collection("classMember")->find_one({teacherCode=>$gr->{teacherCode}});
	if(!$class){
		return jr() unless assert(0,"教师号不存在","教师号不存在","教师号不存在");
	}
	
	my $student = mdb()->get_collection("studentRoster")->find_one({teacherCode=>$gr->{teacherCode}, studentName=>$gr->{studentName}});
	if($student){
		return jr() unless assert(0,"该同学已存在","该同学已存在","该同学已存在");
	}
	
	my $studentRoster = {
		_id => obj_id(),
		type => "studentRoster",
		teacherCode => $gr->{teacherCode},
		studentName => $gr->{studentName},
		#studentNum => $gr->{teacherCode}.$index,
	};
	
	if(length($gr->{phoneNum})){
		$studentRoster->{phoneNum} = $gr->{phoneNum};
	}

	obj_write($studentRoster);

	return jr();
}

$p_studentRoster_add =<<EOF;
后台管理,添加学生名单

输入：
	{
		"obj":"studentRoster",
		"act":"add",
		"studentName":"张三",
		"phoneNum":"",					学生电话,可不传
		"teacherCode":"AA001001"		班级编码,例如:AA001001
	}
EOF

sub p_studentRoster_get{
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");

	my $class = mdb()->get_collection("classMember")->find_one({teacherCode=>$gr->{teacherCode}});
	if(!$class){
		return jr() unless assert(0,"教师号不存在","教师号不存在","教师号不存在");
	}
	
	my @studentList = mdb()->get_collection("studentRoster")->find({teacherCode=>$gr->{teacherCode}})->all();

	return jr({studentList=>\@studentList});
}

$p_studentRoster_get =<<EOF;
后台管理,获取学生名单

输入：
	{
		"obj":"studentRoster",
		"act":"add",
		"teacherCode":"AA001001"		班级编码,例如:AA001001
	}
EOF

#sub p_TeacherCode_check{
#	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");
#	
#	my $teacher = mdb()->get_collection("SchoolMember")->find_one({position=>"teacher", teacherCode=>$gr->{teacherCode}});
#
#	if(!$teacher){
#		return jr() unless assert(0,"教师号不存在","教师号不存在","教师号不存在");
#	}
#
#	return jr();
#}
#
#$p_TeacherCode_check =<<EOF;
#检查老师号是否存在
#
#输入：
#	{
#		"obj":"TeacherCode",
#		"act":"check",
#		"teacherCode":""
#	}
#EOF
#
#sub p_classInfo_get{
#	return jr() unless assert(length($gr->{teacherCode}),"teacherCode 参数少了","teacherCode","teacherCode 参数少了");
#	
#	my $teacher = mdb()->get_collection("SchoolMember")->find_one({position=>"teacher", teacherCode=>$gr->{teacherCode}});
#
#	if(!$teacher){
#		return jr() unless assert(0,"教师号不存在","教师号不存在","教师号不存在");
#	}
#
#	return jr({school=>$teacher->{school}, grade=>$teacher->{grade}, class=>$teacher->{class}});
#}
#
#$p_classInfo_get =<<EOF;
#根据老师号获取学校,年级,班级
#
#输入：
#	{
#		"obj":"classInfo",
#		"act":"get",
#		"teacherCode":""
#	}
#输出:
#	{
#		"school":"",		学校
#		"grade":"",			年级
#		"class":""			班级
#	}
#EOF

sub p_student_check{
	return jr() unless assert($gr->{studentName},"studentName 参数少了","studentName","studentName 参数少了");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");

	my $class = mdb()->get_collection("classMember")->find_one({teacherCode=>$gr->{teacherCode}});

	if(!$class){
		return jr() unless assert(0,"教师号不存在","教师号不存在","教师号不存在");
	}
	
	my $student = mdb()->get_collection("studentRoster")->find_one({teacherCode=>$gr->{teacherCode}, studentName=>$gr->{studentName}});
	
	#my $result = "";
	if($student){
		my $person = mdb()->get_collection("person")->find_one({teacherCode=>$gr->{teacherCode}, name=>$gr->{studentName}});
		
		if($person){
			return jr() unless assert(0,"该学生已注册","该学生已注册","该学生已注册");
		}
		#$result = "是";
		return jr({school=>$class->{school}, grade=>$class->{grade}, class=>$class->{class}});
	}else{
		return jr() unless assert(0,"学生姓名错误","学生姓名错误","学生姓名错误");
		#$result = "否";
	}
	
	return jr({result=>$result});
}

$p_student_check =<<EOF;
检测学生是否在名单中

输入：
	{
		"obj":"student",
		"act":"check",
		"studentName":"",
		"teacherCode":"AA001001"		班级编码,例如:AA001001
	}
输出：
	{
		"school":"",		学校
		"grade":"",			年级
		"class":""			班级
	}
EOF

sub p_city_add{
	return jr() unless assert($gr->{city},"city 参数少了","city","city 参数少了");
	return jr() unless assert($gr->{cityCode},"cityCode 参数少了","cityCode","cityCode 参数少了");
	my $city = {
		_id => obj_id(),
		type => "city",
		city => $gr->{city},
		cityCode => $gr->{cityCode},
	};	
	
	obj_write($city);
	return jr();
}

$p_city_add =<<EOF;
后台管理添加市

输入：
	{
		"obj":"city",
		"act":"add",
		"city":"",
		"cityCode":""
	}
EOF

sub p_area_add{
	return jr() unless assert($gr->{area},"area 参数少了","area","area 参数少了");
	return jr() unless assert($gr->{areaCode},"areaCode 参数少了","areaCode","areaCode 参数少了");
	return jr() unless assert($gr->{cityId},"cityId 参数少了","cityId","cityId 参数少了");

	my $city = mdb()->get_collection("city")->find_one({_id => $gr->{cityId}});
	if(!$city){
		return jr() unless assert(0, "城市不存在", "城市不存在", "城市不存在");
	}
	
	my $areaCode = $city->{cityCode}.$gr->{areaCode};
	my $area = {
		_id => obj_id(),
		type => "area",
		area => $gr->{area},
		areaCode => $areaCode,
		city => $city->{city},
		#cityId => $gr->{cityId},
	};	
	
	obj_write($area);
	return jr();
}

$p_area_add =<<EOF;
后台管理添加区

输入：
	{
		"obj":"area",
		"act":"add",
		"area":"",
		"areaCode":"",
		"cityId":""
	}
EOF

sub p_cityList_get{

	my @cityList = mdb()->get_collection("city")->find()->all();
	
	return jr({cityList=>\@cityList});
}

$p_cityList_get =<<EOF;
获取市列表

输入：
	{
		"obj":"cityList",
		"act":"get"
	}
输出：
	{
		"cityList":[]
	}
EOF

sub p_areaList_get{
	return jr() unless assert($gr->{cityId},"cityId 参数少了","cityId","cityId 参数少了");

	my @areaList = mdb()->get_collection("area")->find({city => $gr->{city}})->all();
	
	return jr({areaList=>\@areaList});
}

$p_areaList_get =<<EOF;
根据城市获取区列表

输入：
	{
		"obj":"areaList",
		"act":"get",
		"city":""
	}
输出：
	{
		"areaList":[]
	}
EOF

sub p_cityAndArea_get{
	my @cityList = mdb()->get_collection("city")->find()->all();
	my @citys = ();
	
	foreach my $item(@cityList){
		my @areas = ();
		
		my @areaList = mdb()->get_collection("area")->find({cityName => $item->{cityName}})->all();
		
		foreach my $areaItem(@areaList){
			my $areaTmp = {
				name => $areaItem->{areaName},
				id => $areaItem->{_id},
			};
			push @areas, $areaTmp;
		}
		
		my $cityItem = {
			name => $item->{cityName},
			id => $item->{_id},
			areas => \@areas,
		};
		
		push @citys, $cityItem;
	}
	
	return jr({citys=>\@citys});
}
 


$p_cityAndArea_get =<<EOF;
获取市区列表

输入：
	{
		"obj":"cityAndArea",
		"act":"get"
	}
输出：
	{
		"cities":[
		{
			"city":"福州市",
			"cityCode":"",
			"cityId":"",
			"areas":[
				{
					"area":"鼓楼区",
					"areaCode":"",
					"cityId":"",
					"areaId":"",
					
				}
			]
		}
	]
	}
EOF

sub p_schoolList_get{
	my %regex = ('$regex'=>"regex");
	my %data = ();
	my @conditionalKeys = keys %{$gr->{data}};
	foreach my $item (@conditionalKeys){
		if(!$gr->{data}->{$item}){
			next;
		}
	
		#if($item eq "startTime"){
		#	$startTime = $gr->{data}->{"startTime"};
		#	last;
		#}
		
		#if($item eq "endTime"){
		#	$endTime = $gr->{data}->{"endTime"};
		#	last;
		#}
		
		if($item eq "school"){
			$regex{'$regex'} = $gr->{data}->{$item};
			$data{$item} = \%regex;
		}
		elsif($item eq "areaId"){
			my $area = mdb()->get_collection("area")->find_one({_id=>$gr->{data}->{$item}});
			
			$data{"areaCode"} = $area->{areaCode};
		}
		else{
			$data{$item} = $gr->{data}->{$item};
		}
	}
	
	my @schoolList = mdb()->get_collection("SchoolMember")->find(\%data)->all();

	return jr({schoolList=>\@schoolList});
}

$p_schoolList_get =<<EOF;
获取学校列表

输入：
	{
		"obj":"schoolList",
		"act":"get",
		"data":
		{
			"areaId":"o15384884048801939487"
		}
	}
输出：
	{
		"schoolList":[]
	}
EOF

sub p_person_delete{
	return jr() unless assert($gr->{login_name},"login_name 参数少了","login_name","login_name 参数少了");
	
	my $account = mdb()->get_collection("account")->find_one({login_name=>$gr->{login_name}});
	
	if($account){
		my $personId = $account->{pids}->{default};
		my $perf = obj_delete("person", $personId);
		
		obj_delete("account", $account->{_id});
	}
	return jr();
}

#end 后台管理

#begin 教师端
sub p_homework_publish{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");
	
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "只有教师才能发布作业", "只有教师才能发布作业", "只有教师才能发布作业");
	}

	my $chapter = mdb()->get_collection("chapter")->find_one({_id=>$gr->{chapterId}});

	if(!$chapter){
		return assert(0,"章节资源不存在","not found","章节资源不存在");
	}
	
	my $books = mdb()->get_collection("books")->find_one({_id=>$chapter->{booksId}});

	if(!$books){
		return assert(0,"课本资源不存在","not found","课本资源不存在");
	}
	
	if($books->{status} ne "上架"){	
		return jr() unless assert(0,"该课本已下架","该课本已下架","该课本已下架");
	}
	
	my $days = days_calculate($gr->{startTime}, $gr->{finishTime});
	
	my $homework = {
		_id => obj_id(),
		type => "homework",
		teacherId => $pref->{_id},
		teacherCode => $gr->{teacherCode},
		booksId => $chapter->{booksId},
		bookName => $chapter->{name},
		chapterId => $chapter->{_id},
		chapterNum => $chapter->{chapterNum},
		chapterName => $chapter->{name},
		pageSpacing => $gr->{pageSpacing},
		category => $books->{category},
		startTime => $gr->{startTime},
		finishTime => $gr->{finishTime},
		readDays => $days,
		readType => $gr->{readType},
		publishState => "进行中",
		publistTime => time(),
	};

	obj_write($homework);
	return jr();
}

#$p_homework_publish =<<EOF;
#教师端发布作业
#
#输入：
#	{
#		"obj":"homework",
#		"act":"publish",
#		"chapterId":"",
#		"pageSpacing":"",
#		"startTime":"",
#		"finishTime":"",
#		"readType":"",						类型(朗读/默读)
#		"publishState":"",					发布状态(进行中/已取消)
#		"teacherCode":""
#	}
#EOF

#sub p_homework_modify{
#	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
#	return jr() unless assert($gr->{homeworkId},"homeworkId 参数少了","homeworkId","homeworkId 参数少了");
#
#	my $pref = obj_read("person", $gs->{pid});
#	if(!$pref){
#		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
#	}
#	
#	if($pref->{position} ne "teacher"){
#		return jr() unless assert(0, "只有教师才能修改作业", "只有教师才能修改作业", "只有教师才能修改作业");
#	}
#
#	my $homework = mdb()->get_collection("homework")->find_one({_id=>$gr->{homeworkId}});
#	if(!$homework){
#		return assert(0,"作业id错误","作业id错误","作业id错误");
#	}
#
#	if($gr->{startTime}){
#		$homework->{startTime} = $gr->{startTime};
#		my $days = ($homework->{finishTime} - $homework->{startTime} )/(60*60*24);
#		$homework->{readDays} = $days;
#	}
#	
#	if($gr->{finishTime}){
#		my $changeTime = $homework->{finishTime} - $gr->{finishTime};
#		
#		$homework->{finishTime} = $gr->{finishTime};
#		my $days = ($homework->{finishTime} - $homework->{startTime} )/(60*60*24);
#		$homework->{readDays} = $days;
#		
#		my $currentNum = $homework->{chapterNum};
#		my @homeworkList = mdb()->get_collection("homework")->find({booksId=>$homework->{booksId}})->sort({"chapterNum"=>1})->all();
#		foreach my $item(@homeworkList){
#			if($item->{chapterNum} > $currentNum){
#				$item->{finishTime} += $changeTime;
#				$item->{startTime} += $changeTime;
#				obj_write($item);
#			}
#		}
#	}
#	
#	if($gr->{readType}){
#		$homework->{readType} = $gr->{readType};
#	}
#	
#	if($gr->{publishState}){
#		$homework->{publishState} = $gr->{publishState};
#	}
#	
#	obj_write($homework);
#	return jr();
#}

sub p_homework_modify{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{homeworkList},"homeworkList 参数少了","homeworkList","homeworkList 参数少了");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");

	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "只有教师才能修改作业", "只有教师才能修改作业", "只有教师才能修改作业");
	}

	my $booksHomeworkInfo;
	my $booksStartTime = 0;
	my $booksFinishTime = 0;
	
	foreach my $item (@{$gr->{homeworkList}}){
		my $homework = mdb()->get_collection("homework")->find_one({_id=>$item->{homeworkId}});
		if($homework){
			$homework->{startTime} = $item->{startTime};
			$homework->{finishTime} = $item->{finishTime};
			my $days = days_calculate($homework->{startTime}, $homework->{finishTime});
			$homework->{readDays} = $days;
			$homework->{readType} = $item->{readType};
			
			if(!$booksHomeworkInfo){
				$booksHomeworkInfo = mdb()->get_collection("booksHomeworkInfo")->find_one({booksId=>$homework->{booksId}, teacherCode=>$gr->{teacherCode}});
				#$booksStartTime = $booksHomeworkInfo->{startTime};
				#$booksFinishTime = $booksHomeworkInfo->{finishTime};
			}
			
			if($booksHomeworkInfo){
				if($booksStartTime == 0){
					$booksStartTime = $item->{startTime};
				}
				else{
					if($item->{startTime} < $booksStartTime){
						$booksStartTime = $item->{startTime};
					}
				}
				
				if($booksFinishTime == 0){
					$booksFinishTime = $item->{finishTime};
				}
				else{
					if($item->{finishTime} > $booksFinishTime){
						$booksFinishTime = $item->{finishTime};
					}
				}
			}
			obj_write($homework);
		}
	}

	$booksHomeworkInfo->{startTime} = $booksStartTime;
	$booksHomeworkInfo->{finishTime} = $booksFinishTime;
	obj_write($booksHomeworkInfo);
	
	return jr();
}

$p_homework_modify =<<EOF;
教师端修改作业

输入：
	{
		"obj":"homework",
		"act":"modify",
		"teacherCode":"AA001478",
		"homeworkList":[
			{
				"homeworkId":"",
				"startTime":123,				当天00:00:00
				"finishTime":123,				当天23:59:59,就是凌晨减1
				"readType":"",						类型(朗读/默读)
			}
		]
	}
EOF

sub p_homework_change{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{homeworkId},"homeworkId 参数少了","homeworkId","homeworkId 参数少了");
	return jr() unless assert($gr->{publishType},"publishType 参数少了","publishType","publishType 参数少了");

	if($gr->{publishType} ne "发布" and $gr->{publishType} ne "取消"){
		return jr() unless assert(0,"publishType 参数错误","publishType","publishType 参数错误");
	}
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "只有教师才能修改作业", "只有教师才能修改作业", "只有教师才能修改作业");
	}

	my $homework = mdb()->get_collection("homework")->find_one({_id=>$gr->{homeworkId}});
	if(!$homework){
		return assert(0,"作业id错误","作业id错误","作业id错误");
	}

	if($homework->{publishState} ne $gr->{publishType}){
		$homework->{publishState} = $gr->{publishType};
		obj_write($homework);
	}

	return jr();
}

$p_homework_change =<<EOF;
教师端发布和取消发布作业

输入：
	{
		"obj":"homework",
		"act":"change",
		"homeworkId":"",
		"publishType":""			发布/取消
	}
EOF

sub p_booksHomework_cancel{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{booksId},"booksId 参数少了","booksId","booksId 参数少了");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");

	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "只有教师才能修改作业", "只有教师才能修改作业", "只有教师才能修改作业");
	}

	my @teacherCodeList = keys %{$pref->{teacherCodeList}};
	
	if(!exists(${$pref->{teacherCodeList}}{$gr->{teacherCode}})){
		return jr() unless assert(0, "教师未管理该班级", "教师未管理该班级", "教师未管理该班级");
	}
	
	my $booksHomeworkInfo = mdb()->get_collection("booksHomeworkInfo")->find_one({booksId=>$gr->{booksId}, teacherCode=>$gr->{teacherCode}});
	if(!$booksHomeworkInfo){
		return assert(0,"该课本未发布作业","该课本未发布作业","该课本未发布作业");
	}
	
	if($booksHomeworkInfo->{startTime} < time()){
		return assert(0,"已开始的作业无法取消","已开始的作业无法取消","已开始的作业无法取消");
	}
	
	obj_delete("booksHomeworkInfo", $booksHomeworkInfo->{_id});
	
	my @homeworkList = mdb()->get_collection("homework")->find({teacherCode=>$gr->{teacherCode}, booksId=>$gr->{booksId}})->all();

	foreach my $item(@homeworkList){
		obj_delete("homework", $item->{_id});
	}

	return jr();
}

$p_booksHomework_cancel =<<EOF;
取消课本对应发布的所有作业

输入：
	{
		"obj":"booksHomework",
		"act":"cancel",
		"booksId":"",
		"teacherCode":""
	}
EOF

sub p_booksHomeworkStatus_check{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{booksId},"booksId 参数少了","booksId","booksId 参数少了");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");

	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "只有教师才能修改作业", "只有教师才能修改作业", "只有教师才能修改作业");
	}

	my @teacherCodeList = keys %{$pref->{teacherCodeList}};
	
	if(!exists(${$pref->{teacherCodeList}}{$gr->{teacherCode}})){
		return jr() unless assert(0, "教师未管理该班级", "教师未管理该班级", "教师未管理该班级");
	}
	
	my $booksHomeworkInfo = mdb()->get_collection("booksHomeworkInfo")->find_one({booksId=>$gr->{booksId}, teacherCode=>$gr->{teacherCode}});
	if(!$booksHomeworkInfo){
		return assert(0,"该课本未发布作业","该课本未发布作业","该课本未发布作业");
	}
	
	my $status = "";
	if($booksHomeworkInfo->{startTime} < time()){
		$status = "否";
	}else{
		$status = "是";
	}

	return jr({status=>$status});
}

$p_booksHomeworkStatus_check =<<EOF;
判断课本发布的作业是否可以取消

输入：
	{
		"obj":"booksHomeworkStatus",
		"act":"check",
		"booksId":"",
		"teacherCode":""
	}
输出：
	{
		"status":""			是-> 可以取消,否->不可以取消
	}
EOF

sub p_booksHomework_publish{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");
	return jr() unless assert($gr->{booksId},"booksId 参数少了","booksId","booksId 参数少了");
	
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "只有教师才能发布作业", "只有教师才能发布作业", "只有教师才能发布作业");
	}
	
	#my $chapter = mdb()->get_collection("chapter")->find_one({_id=>$gr->{chapterId}});
    #
	#if(!$chapter){
	#	return assert(0,"章节资源不存在","not found","章节资源不存在");
	#}
	
	my $books = mdb()->get_collection("books")->find_one({_id=>$gr->{booksId}});
	if(!$books){
		return assert(0,"课本资源不存在","not found","课本资源不存在");
	}
	if($books->{status} ne "上架"){	
		return jr() unless assert(0,"该课本已下架","该课本已下架","该课本已下架");
	}
	
	my $currentTime = time();
	
	homework_update($gr->{teacherCode}, $gr->{booksId});
	
	#my $booksHomeworkInfo = mdb()->get_collection("booksHomeworkInfo")->find_one({teacherCode=>$gr->{teacherCode}, startTime =>{'$lt'=>$currentTime}, finishTime =>{'$gt'=>$currentTime}});
	my @booksHomeworkInfoList = mdb()->get_collection("booksHomeworkInfo")->find({teacherCode=>$gr->{teacherCode}})->sort({"publistTime"=>-1})->all();
	if(scalar(@booksHomeworkInfoList) and $booksHomeworkInfoList[0] and $booksHomeworkInfoList[0]->{publishState} ne "已完成"){
		return assert(0, "该班级已有作业", "该班级已有作业", "该班级已有作业");
	}
	
	$booksHomeworkInfo = mdb()->get_collection("booksHomeworkInfo")->find_one({booksId=>$gr->{booksId}, teacherCode=>$gr->{teacherCode}});
	if($booksHomeworkInfo and $booksHomeworkInfo->{finishTime} < $currentTime){
		return assert(0,"该课程已完成,不能再次布置","该课程已完成,不能再次布置","该课程已完成,不能再次布置");
	}
	
	#my $homeworkOld = mdb()->get_collection("homework")->find_one({teacherCode=>$gr->{teacherCode}, startTime =>{'$lt'=>$currentTime}, finishTime =>{'$gt'=>$currentTime}});
	#if($homeworkOld){
	#	return assert(0, "该班级已有作业", "该班级已有作业", "该班级已有作业");
	#}
	
	#my @chapterIdList = @{$books->{chapterList}};
	my @chapterIdList = values %{$books->{ChapterID}};
	my @chapterList = @{$gr->{chapterList}};
	
	my $chapterIdCount = @chapterIdList;
	my $chapterIdCountTmp = @chapterList;
	
	if($chapterIdCount != $chapterIdCountTmp){
		return assert(0,"chapterList 个数错误","chapterList 个数错误","chapterList 个数错误");
	}
	
	my @homeworkList = ();
	
	my $booksStartTime = 0;
	my $booksFinishTime = 0;
	foreach my $item(@chapterList){
		my $chapter = mdb()->get_collection("chapter")->find_one({_id=>$item->{chapterId}});
		if(!$chapter){
			next;
		}
		my $days = days_calculate($item->{startTime}, $item->{finishTime});
		my $status = "未开始";
		if($currentTime > $item->{startTime} and $currentTime < $item->{finishTime}){
			$status = "进行中";
		}
		
		my $homework = mdb()->get_collection("homework")->find_one({chapterId=>$chapter->{_id}, teacherCode=>$gr->{teacherCode}});
		if(!$homework)
		{
			$homework = {
				_id => obj_id(),
				type => "homework",
				teacherId => $pref->{_id},
				teacherCode => $gr->{teacherCode},
				booksId => $chapter->{booksId},
				bookName => $books->{name},
				chapterId => $chapter->{_id},
				chapterNum => $chapter->{chapterNum},
				chapterName => $chapter->{name},
				category => $books->{category},
				publistTime => $currentTime,
			};
		}
		
		$homework->{pageSpacing} = $chapter->{chapterPage};
		$homework->{startTime} = $item->{startTime};
		$homework->{finishTime} = $item->{finishTime};
		$homework->{readDays} = $days;
		$homework->{readType} = $item->{readType};
		$homework->{publishState} = $status;
		
		if($booksStartTime == 0){
			$booksStartTime = $item->{startTime};
		}
		else{
			if($item->{startTime} < $booksStartTime){
				$booksStartTime = $item->{startTime};
			}
		}
		
		if($booksFinishTime == 0){
			$booksFinishTime = $item->{finishTime};
		}
		else{
			if($item->{finishTime} > $booksFinishTime){
				$booksFinishTime = $item->{finishTime};
			}
		}
		
		obj_write($homework);
		push @homeworkList, $homework;
	}
	
	my $booksDays = $booksFinishTime - $booksStartTime + 1;
	my $booksStatus = "未开始";
	if($booksDays > 0){
		$booksDays = days_calculate($booksStartTime, $booksFinishTime);
		$booksStatus = "进行中";
	}
	else{
		$booksDays = 0;
	}
	
	my $booksHomeworkInfoTmp = mdb()->get_collection("booksHomeworkInfo")->find_one({booksId=>$gr->{booksId}, teacherCode=>$gr->{teacherCode}});
	if(!$booksHomeworkInfoTmp){
		$booksHomeworkInfoTmp = {
			_id => obj_id(),
			type => "booksHomeworkInfo",
			teacherId => $pref->{_id},
			teacherCode => $gr->{teacherCode},
			booksId => $books->{_id},
			bookName => $books->{name},
			category => $books->{category},
			startTime => $booksStartTime,
			finishTime => $booksFinishTime,
			readDays => $booksDays,
			publishState => $booksStatus,
			publistTime => $currentTime,
		};
	}else{
		$booksHomeworkInfoTmp->{startTime} = $booksStartTime;
		$booksHomeworkInfoTmp->{finishTime} = $booksFinishTime;
		$booksHomeworkInfoTmp->{readDays} = $booksDays;
	}
	
	obj_write($booksHomeworkInfoTmp);
	
	my @homeworkListTmp = sort { $a->{chapterNum} <=> $b->{chapterNum} } @homeworkList if(scalar @homeworkList);
	
	return jr({homeworkList=>\@homeworkListTmp});
}

$p_booksHomework_publish =<<EOF;
教师端根据课本发布作业

输入：
	{
		"obj":"booksHomework",
		"act":"publish",
		"booksId":"",
		"teacherCode":"",
		"chapterList":[
			{
				"chapterId":"",
				"startTime":123,				当天00:00:00
				"finishTime":123,				当天23:59:59,就是凌晨减1
				"pageSpacing":"",
				"readType":"",					类型(朗读/默读)
			}
		]
	}
输出：
{
	"homeworkList":[]
}
EOF

sub homework_update{
	my $teacherCode = $_[0];
	my $booksId = $_[1];
	my $currentTime = time();
	
	my @homeworkList = mdb()->get_collection("homework")->find({booksId=>$booksId, teacherCode=>$teacherCode})->all();
	
	my $flag = "未开始";
	foreach my $item (@homeworkList){
		if($item->{finishTime} < $currentTime){
			$item->{publishState} = "已完成";
			if($flag ne "进行中"){
				$flag = "已完成";
			}
		}
		elsif($item->{startTime} < $currentTime
			and $item->{finishTime} > $currentTime){
			$item->{publishState} = "进行中";
			$flag = "进行中";
		}
		obj_write($item);
	}
	
	my $booksHomeworkInfo = mdb()->get_collection("booksHomeworkInfo")->find_one({teacherCode=>$teacherCode,booksId=>$booksId});
	if($booksHomeworkInfo){
		$booksHomeworkInfo->{publishState} = $flag;
		obj_write($booksHomeworkInfo);
	}
	
	return jr();
}

sub p_booksHomework_check{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");
	return jr() unless assert($gr->{booksId},"booksId 参数少了","booksId","booksId 参数少了");
	
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "权限不足", "权限不足", "权限不足");
	}
	
	my $books = mdb()->get_collection("books")->find_one({_id=>$gr->{booksId}});

	if(!$books){
		return assert(0,"课本资源不存在","not found","课本资源不存在");
	}
	
	if($books->{status} ne "上架"){	
		return jr() unless assert(0,"该课本已下架","该课本已下架","该课本已下架");
	}
	
	my $result = "否";
	
	my $currentTime = time();
	#my $booksHomeworkInfo = mdb()->get_collection("booksHomeworkInfo")->find_one({teacherCode=>$gr->{teacherCode}, startTime =>{'$lt'=>$currentTime}, finishTime =>{'$gt'=>$currentTime}});
	
	my $booksHomeworkInfo = mdb()->get_collection("booksHomeworkInfo")->find_one({teacherCode=>$gr->{teacherCode},booksId=>$gr->{booksId}});
	
	my $result = "否";
	#if($booksHomeworkInfo and $booksHomeworkInfo->{booksId} eq $gr->{booksId}){
	if($booksHomeworkInfo){
		$result = "是";
	}
	
	return jr({result=>$result});
}

$p_booksHomework_check =<<EOF;
教师端根据课本检测是否已经发布作业

输入：
	{
		"obj":"booksHomework",
		"act":"check",
		"booksId":"",
		"teacherCode":""
	}
输出：
	{
		"result":""				是->已有对应的作业,否->没有作业。
	}
EOF

sub p_booksHomeworkList_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");
	return jr() unless assert($gr->{booksId},"booksId 参数少了","booksId","booksId 参数少了");
	
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "不是教师,无法获取", "不是教师,无法获取", "不是教师,无法获取");
	}
	
	my $books = mdb()->get_collection("books")->find_one({_id=>$gr->{booksId}});

	if(!$books){
		return assert(0,"课本资源不存在","not found","课本资源不存在");
	}
	if($books->{status} ne "上架"){	
		return jr() unless assert(0,"该课本已下架","该课本已下架","该课本已下架");
	}
	
	my @chapterIdList = values %{$books->{ChapterID}};
	
	my $currentTime = time();
	my @homeworkList = ();
	foreach my $item(@chapterIdList){
		my $chapter = mdb()->get_collection("chapter")->find_one({_id=>$item});
		if(!$chapter){
			next;
		}
		
		my $homework = mdb()->get_collection("homework")->find_one({chapterId=>$chapter->{_id}, teacherCode=>$gr->{teacherCode}});
		#if(!$homework)
		#{
		#	$homework = {
		#		_id => obj_id(),
		#		type => "homework",
		#		teacherId => $pref->{_id},
		#		teacherCode => $gr->{teacherCode},
		#		booksId => $chapter->{booksId},
		#		bookName => $chapter->{name},
		#		chapterId => $chapter->{_id},
		#		chapterNum => $chapter->{chapterNum},
		#		chapterName => $chapter->{chapterName},
		#		pageSpacing => $chapter->{chapterPage},
		#		category => $books->{category},
		#		startTime => 0,
		#		finishTime => 0,
		#		readDays => 0,
		#		readType => "",
		#		publishState => "未开始",
		#		publistTime => $currentTime,
		#	};
		#
		#	obj_write($homework);
		#}
		if(!$homework)
		{
			$homework = {
				teacherId => $pref->{_id},
				teacherCode => $gr->{teacherCode},
				booksId => $chapter->{booksId},
				bookName => $books->{name},
				chapterId => $chapter->{_id},
				chapterNum => $chapter->{chapterNum},
				chapterName => $chapter->{name},
				pageSpacing => $chapter->{chapterPage},
				category => $books->{category},
				startTime => 0,
				finishTime => 0,
				readDays => 0,
				readType => "",
				publishState => "未开始",
			};
		}
		if($homework){
			push @homeworkList, $homework;
		}
	}
	
	#my $booksHomeworkInfoTmp = mdb()->get_collection("booksHomeworkInfo")->find_one({booksId=>$gr->{booksId}, teacherCode=>$gr->{teacherCode}});
	#if(!$booksHomeworkInfoTmp){
	#	$booksHomeworkInfoTmp = {
	#		_id => obj_id(),
	#		type => "booksHomeworkInfo",
	#		teacherId => $pref->{_id},
	#		teacherCode => $gr->{teacherCode},
	#		booksId => $books->{_id},
	#		bookName => $books->{name},
	#		category => $books->{category},
	#		startTime => 0,
	#		finishTime => 0,
	#		readDays => 0,
	#		publishState => "未开始",
	#		publistTime => $currentTime,
	#	};
	#}
	#obj_write($booksHomeworkInfoTmp);
	
	my @homeworkListTmp = sort { $a->{chapterNum} <=> $b->{chapterNum} } @homeworkList if(scalar @homeworkList);
	
	return jr({homeworkList=>\@homeworkListTmp});
}

$p_booksHomeworkList_get =<<EOF;
教师端根据课本获取作业

输入：
	{
		"obj":"booksHomeworkList",
		"act":"get",
		"booksId":"",
		"teacherCode":""
	}
输出：
{
	"homeworkList":[]
}
EOF

sub p_homeworkList_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");
	
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "只有教师才能查看作业", "只有教师才能查看作业", "只有教师才能查看作业");
	}

	#my $chapter = mdb()->get_collection("chapter")->find_one({_id=>$gr->{chapterId}});
    #
	#if(!$chapter){
	#	return assert(0,"章节资源不存在","not found","章节资源不存在");
	#}
	#
	#my $books = mdb()->get_collection("books")->find_one({_id=>$chapter->{booksId}});
    #
	#if(!$books){
	#	return assert(0,"课本资源不存在","not found","课本资源不存在");
	#}
	
	#my @homeworkList = mdb()->get_collection("homework")->find({teacherId=>$gs->{pid}, teacherCode=>$gr->{teacherCode}})->sort({"publistTime"=>-1})->all();
	
	my $currentTime = time();
	my $booksId = "";
	
	my $homeworkOld = mdb()->get_collection("homework")->find_one({teacherCode=>$gr->{teacherCode}, startTime =>{'$lt'=>$currentTime}, finishTime =>{'$gt'=>$currentTime}});
	if($homeworkOld){
		$booksId = $homeworkOld->{booksId};
	}
	else{
		my @homeworkListTmp = mdb()->get_collection("homework")->find({teacherId=>$gs->{pid}, teacherCode=>$gr->{teacherCode}, finishTime =>{'$gt'=>$currentTime}})->sort({"publistTime"=>-1})->all();
		if(scalar @homeworkListTmp){
			$booksId = $homeworkListTmp[0]->{booksId};
		}
	}	

	if(length($booksId)){
		homework_update($gr->{teacherCode}, $booksId);
	}
	
	#my @homeworkList = mdb()->get_collection("homework")->find({teacherId=>$gs->{pid}, teacherCode=>$gr->{teacherCode}, finishTime =>{'$gt'=>$currentTime}})->sort({"publistTime"=>-1})->all();
	
	my @homeworkList = mdb()->get_collection("homework")->find({teacherId=>$gs->{pid}, teacherCode=>$gr->{teacherCode}, startTime =>{'$lt'=>$currentTime}, finishTime =>{'$gt'=>$currentTime}})->all();
	
	my @homeworkListTmp = sort { $a->{chapterNum} <=> $b->{chapterNum} } @homeworkList if(scalar @homeworkList);
	
	return jr({homeworkList=>\@homeworkListTmp});
}

$p_homeworkList_get =<<EOF;
教师端查看课程

输入：
	{
		"obj":"homeworkList",
		"act":"get",
		"teacherCode":""
	}
输出:
	{
		"homeworkList":[]
	}
EOF

sub p_homeworkFinishCount_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");
	
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "只有教师才能发布作业", "只有教师才能发布作业", "只有教师才能发布作业");
	}

	my $chapter = mdb()->get_collection("chapter")->find_one({_id=>$gr->{chapterId}});

	if(!$chapter){
		return assert(0,"章节资源不存在","not found","章节资源不存在");
	}
	
	my $books = mdb()->get_collection("books")->find_one({_id=>$chapter->{booksId}});

	if(!$books){
		return assert(0,"课本资源不存在","not found","课本资源不存在");
	}
	if($books->{status} ne "上架"){	
		return jr() unless assert(0,"该课本已下架","该课本已下架","该课本已下架");
	}
	
	my @chapterScheduleList = mdb()->get_collection("chapterSchedule")->find({chapterID=>$gr->{chapterID}, teacherCode=>$gr->{teacherCode}})->all();
	my $undone = @chapterScheduleList;
	my $finishCount = 0;
	
	if($gr->{type} eq "导读"){
		my @chapterScheduleListTmp = mdb()->get_collection("chapterSchedule")->find({chapterID=>$gr->{chapterID}, teacherCode=>$gr->{teacherCode}, guideReadingState=>"已完成"})->all();
		$finishCount = @chapterScheduleListTmp;
	}elsif($gr->{type} eq "范读"){
		my @chapterScheduleListTmp = mdb()->get_collection("chapterSchedule")->find({chapterID=>$gr->{chapterID}, teacherCode=>$gr->{teacherCode}, modelReadingState=>"已完成"})->all();
		$finishCount = @chapterScheduleListTmp;
	}elsif($gr->{type} eq "朗读"){
		my @chapterScheduleListTmp = mdb()->get_collection("chapterSchedule")->find({chapterID=>$gr->{chapterID}, teacherCode=>$gr->{teacherCode}, readingAloudState=>"已完成"})->all();
		$finishCount = @chapterScheduleListTmp;
	}elsif($gr->{type} eq "默读"){
		my @chapterScheduleListTmp = mdb()->get_collection("chapterSchedule")->find({chapterID=>$gr->{chapterID}, teacherCode=>$gr->{teacherCode}, silentReadingState=>"已完成"})->all();
		$finishCount = @chapterScheduleListTmp;
	}elsif($gr->{type} eq "章节评测"){
		my @chapterScheduleListTmp = mdb()->get_collection("chapterSchedule")->find({chapterID=>$gr->{chapterID}, teacherCode=>$gr->{teacherCode}, testQuestionsState=>"已完成"})->all();
		$finishCount = @chapterScheduleListTmp;
	}
	
	$undone = $undone - $finishCount;
	return jr({undone=>$undone, finishCount=>$finishCount});
}

#$p_homeworkFinishCount_get =<<EOF;
#教师端获取未完成和已完成数量
#
#输入：
#	{
#		"obj":"homeworkFinishCount",
#		"act":"get",
#		"teacherCode":"",
#		"type":"导读"				导读/范读/朗读/默读/章节评测
#	}
#输出:
#	{
#		"undone":12,
#		"finishCount":12
#	}
#EOF

sub p_classGroup_add{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	#return jr() unless assert($gr->{groupName},"groupName 参数少了","groupName","groupName 参数少了");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "只有教师才能分组", "只有教师才能分组", "只有教师才能分组");
	}

	my $group = mdb()->get_collection("classGroup")->find_one({teacherCode=>$gr->{teacherCode}});
	if(!$group){
		my @personList = mdb()->get_collection("person")->find({teacherCode=>$gr->{teacherCode}})->all();
		my %groupList = ();
		#my @groupList = ();
		foreach my $item(@personList){
			my $student = {
				studentId => $item->{_id},
				studentName => $item->{name},
				avatar_fid => $item->{avatar_fid},
			};
			
			#push @groupList, $student;
			$groupList{$item->{_id}} = $student;
		}

		$group = {
			_id => obj_id(),
			type => "classGroup",
			teacherCode => $gr->{teacherCode},
			otherList => \%groupList,
		};
	}

	my @groupNameList = keys %{$group->{groupList}};
	my $groupCount = @groupNameList;
	$groupCount += 1;
	my $groutName = $groupCount."小组";
	
	#if(exists(${$group->{groupList}}{$gr->{groupName}})){
	#	return jr() unless assert(0, "分组名重复", "分组名重复", "分组名重复");
	#}
	#foreach my $item (@{$group->{groupList}}){
	#	if($item eq $gr->{groupName}){
	#		return jr() unless assert(0, "分组名重复", "分组名重复", "分组名重复");
	#	}
	#}
	
	${$group->{groupList}}{$groutName}->{groupName} = $groutName;
	${$group->{groupList}}{$groutName}->{index} = $groupCount;
	
	#my @studentList = ();
	#foreach my $sutdentItem (@{$gr->{studentList}}){
	#	push @studentList, $group->{otherList}->{$sutdentItem};
	#	delete $group->{otherList}->{$sutdentItem};
	#}
	#my $groupItem = {
	#	groupName => $gr->{groupName},
	#	studentList => @studentList,
	#};
	#push @{$group->{groupList}}, $groupItem;
	
	$group->{updateTime} = time();
	obj_write($group);
	
	my $timedTask = mdb()->get_collection("timedTask")->find_one({teacherCode=>$gr->{teacherCode}});
	$timedTask->{status} = "结束";
	obj_write($timedTask);
	
	return jr({groupName=>$groutName});
}

$p_classGroup_add =<<EOF;
班级学生手动分组

输入：
	{
		"obj":"classGroup",
		"act":"add",
		"groupName":"",			(不需要了)
		"teacherCode":""
	}
输出：
	{
		"groupName":""
	}
EOF

sub p_classGroup_update{
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");

	my $group = mdb()->get_collection("classGroup")->find_one({teacherCode=>$gr->{teacherCode}});
	if(!$group){
		return jr();
	}

	my @personList = mdb()->get_collection("person")->find({teacherCode=>$gr->{teacherCode}})->all();
	
	my @personOtherList = ();
	#my @personFinishList = ();
	my @groupNameList = keys %{$group->{groupList}};

	my $personHash;
	foreach my $item(@personList){
		$personHash->{$item->{_id}} = $item;
	}
	
	foreach my $groupItem(@groupNameList){
		#my $groupList = $group->{groupList}{$groupItem}{studentList};
		#删掉已在分组,但不在班级的学生
		my @studentItemList = keys %{$group->{groupList}{$groupItem}{studentList}};
		foreach my $personItem(@studentItemList){
			if(!exists($personHash{$personItem})){
				delete ${$group->{groupList}}{$groupItem}{studentList}{$personItem};
			}
		}
	}
	
	my @studentItemOtherList = keys %{$group->{otherList}};
	foreach my $personItem(@studentItemOtherList){
		if(!exists($personHash{$personItem})){
			delete ${$group->{otherList}}{$personItem};
		}
	}
	
	foreach my $personItem(@personList){
		my $flag = 0;
		foreach my $groupItem(@groupNameList){
			if(exists($group->{groupList}{$groupItem}{studentList}{$personItem->{_id}})){
				$flag = 1;
				last;
			}
		}
		
		if($flag == 0){
			push @personOtherList, $personItem;
		}else{
			#push @personFinishList, $personItem;
		}
	}
	
	foreach my $item(@personOtherList){
		if(!exists($group->{otherList}{$item->{_id}})){
			my $student = {
				studentId => $item->{_id},
				studentName => $item->{name},
				avatar_fid => $item->{avatar_fid},
			};
			$group->{otherList}{$student->{studentId}} = $student;
		}

	}

	obj_write($group);
	return jr();
}

sub p_classGroupStudent_add{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{groupName},"groupName 参数少了","groupName","groupName 参数少了");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "只有教师才能分组", "只有教师才能分组", "只有教师才能分组");
	}

	my $group = mdb()->get_collection("classGroup")->find_one({teacherCode=>$gr->{teacherCode}});
	if(!$group){
		return jr() unless assert(0, "未创建分组", "未创建分组", "未创建分组");
	}
	
	foreach my $item(@{$gr->{studentList}}){
		${$group->{groupList}}{$gr->{groupName}}->{studentList}{$item->{studentId}} = $item;
		
		delete ${$group->{otherList}}{$item->{studentId}};
	}
	
	#@numbers = (@odd, @even);
	#foreach my $item(@{$group->{groupList}}){
	#	if($gr->{groupName} eq $item->{groupName}){
	#		@{$item->{studentList}} = (@{$item->{studentList}}, @{$gr->{studentList}});
	#		#foreach my $studentItem (@{$gr->{studentList}}){
	#		#	push @{$item->{studentList}}, $studentItem;
	#		#}
	#		last;
	#	}
	#}
	#
	#my @otherList = ();
	#foreach my $otherItem(@{$group->{otherList}}){
	#	my $exist = 0;
	#	foreach my $Item(@{$gr->{studentList}}){	
	#		if($Item->{studentId} eq $otherItem->{studentId}){
	#			$exist = 1;
	#		}
	#	}
	#	if($exist == 0){
	#		push @otherList, $otherItem;
	#	}
	#}
	#$group->{otherList} = \@otherList;
	
	$group->{updateTime} = time();
	obj_write($group);
	
	my $timedTask = mdb()->get_collection("timedTask")->find_one({teacherCode=>$gr->{teacherCode}});
	$timedTask->{status} = "结束";
	obj_write($timedTask);
	
	return jr();
}

$p_classGroupStudent_add =<<EOF;
班级分组中添加学生

输入：
	{
		"obj":"classGroupStudent",
		"act":"add",
		"groupName":"",
		"teacherCode":"",
		"studentList":[
			{
				"tudentId":"xxxxxx",	学生id
				"studentName":"",		学生姓名
				"avatar_fid":"xxx"		头像fid
			}
		],
	}
EOF

sub p_classGroupStudent_change{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{groupName},"groupName 参数少了","groupName","groupName 参数少了");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "只有教师才能分组", "只有教师才能分组", "只有教师才能分组");
	}

	my $group = mdb()->get_collection("classGroup")->find_one({teacherCode=>$gr->{teacherCode}});
	if(!$group){
		return jr() unless assert(0, "未创建分组", "未创建分组", "未创建分组");
	}
	
	my @oldStudentList = values %{${$group->{groupList}}{$gr->{groupName}}->{studentList}};
	
	foreach my $item(@oldStudentList){
		${$group->{otherList}}{$item->{studentId}} = $item;
		
		delete ${${$group->{groupList}}{$gr->{groupName}}->{studentList}}{$item->{studentId}};
	}
	
	foreach my $item(@{$gr->{studentList}}){
		${$group->{groupList}}{$gr->{groupName}}->{studentList}{$item->{studentId}} = $item;
		
		delete ${$group->{otherList}}{$item->{studentId}};
	}

	$group->{updateTime} = time();
	obj_write($group);
	
	my $timedTask = mdb()->get_collection("timedTask")->find_one({teacherCode=>$gr->{teacherCode}});
	$timedTask->{status} = "结束";
	obj_write($timedTask);
	
	return jr();
}

$p_classGroupStudent_change =<<EOF;
班级分组中改变学生

输入：
	{
		"obj":"classGroupStudent",
		"act":"change",
		"groupName":"",
		"teacherCode":"",
		"studentList":[
			{
				"tudentId":"xxxxxx",	学生id
				"studentName":"",		学生姓名
				"avatar_fid":"xxx"		头像fid
			}
		],
	}
EOF

sub p_classGroupStudent_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{groupName},"groupName 参数少了","groupName","groupName 参数少了");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "不是教师,无权限操作", "不是教师,无权限操作", "不是教师,无权限操作");
	}

	my $group = mdb()->get_collection("classGroup")->find_one({teacherCode=>$gr->{teacherCode}});
	if(!$group){
		return jr() unless assert(0, "分组不存在", "分组不存在", "分组不存在");
	}
	
	if(!exists(${$group->{groupList}}{$gr->{groupName}})){
		return jr() unless assert(0, "分组名不存在", "分组名不存在", "分组名不存在");
	}
	
	my %studentHash = %{$group->{groupList}{$gr->{groupName}}->{studentList}};
	my @studentList = values %studentHash;
	return jr({studentList=>\@studentList});
}

$p_classGroupStudent_get =<<EOF;
获取班级分组中的学生列表

输入：
	{
		"obj":"classGroupStudent",
		"act":"get",
		"groupName":"",
		"teacherCode":""
	}
输出：
	{
		"studentList":[
			{
				"tudentId":"xxxxxx",	学生id
				"studentName":"",		学生姓名
				"avatar_fid":"xxx"		头像fid
			}
		]
	}
EOF

sub p_classGroup_delete{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{groupName},"groupName 参数少了","groupName","groupName 参数少了");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "不是教师,无权限操作", "不是教师,无权限操作", "不是教师,无权限操作");
	}

	my $group = mdb()->get_collection("classGroup")->find_one({teacherCode=>$gr->{teacherCode}});
	if(!$group){
		return jr() unless assert(0, "未创建分组", "未创建分组", "未创建分组");
	}
	
	if(!exists(${$group->{groupList}}{$gr->{groupName}})){
		return jr() unless assert(0, "分组名不存在", "分组名不存在", "分组名不存在");
	}
	
	my @studentId = keys %{${$group->{groupList}}{$gr->{groupName}}->{studentList}};
	
	foreach my $item(@studentId){
		#${$group->{groupList}}{$gr->{groupName}}->{studentList}{$item} = $item;
		
		${$group->{otherList}}{$item} = ${$group->{groupList}}{$gr->{groupName}}->{studentList}{$item};
	}
	
	#修改之后分组名称
	my $currentIndex = ${$group->{groupList}}{$gr->{groupName}}->{index};
	my @groupName = keys %{$group->{groupList}};
	
	my $total = @groupName;
	
	my $count = $total;
	
	for(my $num = $currentIndex;$num < $total; $num += 1){
		my $secondNum = $num + 1;
		my $fastName = $num."小组";
		my $secondName = $secondNum."小组";
		
		my $item = ${$group->{groupList}}{$secondName};
		$item->{groupName} = $fastName;
		$item->{index} = $num;
		
		${$group->{groupList}}{$fastName} = $item;
	}
	
	#foreach my $item(@groupName){
	#	if(${$group->{groupList}{$item}->{index} > $currentIndex){
	#		${$group->{groupList}{$item}->{index}
	#	}
	#}
	
	my $deleteName = $total."小组";
	delete ${$group->{groupList}}{$deleteName};
	
	$group->{updateTime} = time();
	obj_write($group);
	
	my $timedTask = mdb()->get_collection("timedTask")->find_one({teacherCode=>$gr->{teacherCode}});
	$timedTask->{status} = "结束";
	obj_write($timedTask);
	
	return jr();
}

$p_classGroup_delete =<<EOF;
删除班级分组

输入：
	{
		"obj":"classGroup",
		"act":"delete",
		"groupName":"",
		"teacherCode":""
	}
EOF

sub p_classGroup_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "不是教师,无权限操作", "不是教师,无权限操作", "不是教师,无权限操作");
	}

	my $group = mdb()->get_collection("classGroup")->find_one({teacherCode=>$gr->{teacherCode}});
	if(!$group){
		#return jr() unless assert(0, "未创建分组", "未创建分组", "未创建分组");
		return jr();
	}
	
	#%groupHash = %{$group->{groupList}};
	#my @groupList = keys %groupHash;
	my @groupNameList = keys %{$group->{groupList}};
	my @groupNameListSort = sort @groupNameList;
	
	my @groupList = ();
	foreach my $item(@groupNameListSort){
		my @valuesList = values %{${$group->{groupList}}{$item}->{studentList}};
		my $count = @valuesList;
		my $groupItem = {
			groupName => $item,
			groupCount => $count,
		};
		
		push @groupList, $groupItem;
	}
	
	my @groupListTmp = sort {$a->{groupName} <=> $b->{groupName}} @groupList;
	
	return jr({groupList=>\@groupListTmp});
}

$p_classGroup_get =<<EOF;
获取班级分组

输入：
	{
		"obj":"classGroup",
		"act":"get",
		"teacherCode":"AA001009"
	}
输出：
	{
		"groupList":[
			"groupName":"111",
			"groupCount":12,
		]
	}
EOF

sub p_classGroupStudent_delete{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{groupName},"groupName 参数少了","groupName","groupName 参数少了");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "不是教师,无权限操作", "不是教师,无权限操作", "不是教师,无权限操作");
	}

	my $group = mdb()->get_collection("classGroup")->find_one({teacherCode=>$gr->{teacherCode}});
	if(!$group){
		return jr() unless assert(0, "未创建分组", "未创建分组", "未创建分组");
	}
	
	if(!exists(${$group->{groupList}}{$gr->{groupName}})){
		return jr() unless assert(0, "分组名不存在", "分组名不存在", "分组名不存在");
	}
	
	foreach my $item(@{$gr->{studentList}}){
		delete ${$group->{groupList}}{$gr->{groupName}}->{studentList}{$item->{studentId}};
		
		${$group->{otherList}}{$item->{studentId}} = $item;
	}
	
	$group->{updateTime} = time();
	obj_write($group);
	
	my $timedTask = mdb()->get_collection("timedTask")->find_one({teacherCode=>$gr->{teacherCode}});
	$timedTask->{status} = "结束";
	obj_write($timedTask);
	
	return jr();
}

$p_classGroupStudent_delete =<<EOF;
删除班级分组学生

输入：
	{
		"obj":"classGroupStudent",
		"act":"delete",
		"groupName":"",
		"teacherCode":"",
		"studentList":[
			{
				"studentId":"xxxxxx",	学生id
				"studentName":"",		学生姓名
				"avatar_fid":"xxx"		头像fid
			}
		],
	}
EOF

sub p_classStudent_remaining{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "只有教师才能分组", "只有教师才能分组", "只有教师才能分组");
	}

	my @studentList = ();
	
	my $group = mdb()->get_collection("classGroup")->find_one({teacherCode=>$gr->{teacherCode}});
	if(!$group){
		my @personList = mdb()->get_collection("person")->find({teacherCode=>$gr->{teacherCode}})->all();
		
		foreach my $item(@personList){
			my $studentTmp = {
				studentId => $item->{_id},
				studentName => $item->{name},
				avatar_fid => $item->{avatar_fid},
			};
			push @studentList, $studentTmp;
		}
	}else{
		@studentList = values %{$group->{otherList}};
	}

	return jr({studentList=>\@studentList});
}

$p_classStudent_remaining =<<EOF;
班级未分组学生

输入：
	{
		"obj":"classStudent",
		"act":"remaining",
		"teacherCode":"AA001478"
	}
输出：
	{
		"studentList":[
			{
				"tudentId":"xxxxxx",	学生id
				"studentName":"",		学生姓名
				"avatar_fid":"xxx"		头像fid
			}
		]
	}
EOF

sub p_classGrouping_random{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{groupsNumber},"groupsNumber 参数少了","groupsNumber","groupsNumber 参数少了");
	return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");
	return jr() unless assert($gr->{intervalDays},"intervalDays 参数少了","intervalDays","intervalDays 参数少了");
	
	my $groupsNumber = $gr->{groupsNumber} + 0;
	my $intervalDays = $gr->{intervalDays} + 0;
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "只有教师才能分组", "只有教师才能分组", "只有教师才能分组");
	}

	my $group = mdb()->get_collection("classGroup")->find_one({teacherCode=>$gr->{teacherCode}});
	if(!$group){
		$group = {
			_id => obj_id(),
			type => "classGroup",
			teacherCode => $gr->{teacherCode},
		};
	}else{
		$group->{groupList} = {};
		$group->{otherList} = {};
	}
	
	my @personList = mdb()->get_collection("person")->find({teacherCode=>$gr->{teacherCode}})->all();
	my $total = @personList;
	my $totalTmp = $total;
	my $grouptotal = $total / $groupsNumber;
	
	my $groupNameHeard = "小组";
	for(my $index = 1; $index <= $groupsNumber; $index = $index + 1){
		my $groupItem;
		$groupItem->{groupName} = $index.$groupNameHeard;
		$groupItem->{index} = $index;
		for(my $groupCount = 1; $groupCount <= $grouptotal; $groupCount = $groupCount + 1){
			my $randCount = int(rand($total));
			my $student = {
				studentId => $personList[$randCount]->{_id},
				studentName => $personList[$randCount]->{name},
				avatar_fid => $personList[$randCount]->{avatar_fid},
			};
			${$groupItem->{studentList}}{$student->{studentId}} = $student;
			#push @{$groupItem->{studentList}}, $student;
			splice(@personList, $randCount, 1);
			$total = $total - 1;
		}
		
		${$group->{groupList}}{$groupItem->{groupName}} = $groupItem;
		#push @{$group->{groupList}}, $groupItem;
	}
	
	my $remainingCount = $totalTmp % $groupsNumber;
	
	my @groupNameList = keys %{$group->{groupList}};
	for(my $index = 0; $index < $remainingCount; $index = $index + 1){
		my $randCount = int(rand($total));
		my $student = {
			studentId => $personList[$randCount]->{_id},
			studentName => $personList[$randCount]->{name},
			avatar_fid => $personList[$randCount]->{avatar_fid},
		};
		
		${${$group->{groupList}}{$groupNameList[$index]}->{studentList}}{$student->{studentId}} = $student;
		#push @{$group->{groupList}[$index]->{studentList}}, $student;
		splice(@personList, $randCount, 1);
		$total = $total - 1;
		
		my $personCount = @personList;
		if($personCount <= 0){
			last;
		}
	}
	
	my $currentTime = time();
	$group->{updateTime} = $currentTime;
	obj_write($group);
	
	#执行linux命令,添加定时任务,注意参数,暂未写
	#my $res = `/root/createCrontab.sh '$currentTime' '$gr->{intervalDays}' '$gr->{teacherCode}'`;
	#更改为创建定时任务表
	my $timedTask = mdb()->get_collection("timedTask")->find_one({teacherCode=>$gr->{teacherCode}});
	if($timedTask){
		$timedTask->{startTime} = time();
		$timedTask->{intervalDays} = $intervalDays;
		$timedTask->{groupsNumber} = $groupsNumber;
		$timedTask->{status} = "开始";
	}else{
		$timedTask->{_id} = obj_id();
		$timedTask->{type} = "timedTask";
		$timedTask->{teacherCode} = $gr->{teacherCode};
		$timedTask->{startTime} = time();
		$timedTask->{intervalDays} = $intervalDays;
		$timedTask->{groupsNumber} = $groupsNumber;
		$timedTask->{status} = "开始";
	}
	obj_write($timedTask);
	
	#return jr({group=>$group});
	#%groupHash = %{$group->{groupList}};
	#my @groupList = keys %groupHash;
	my @groupList = keys %{$group->{groupList}};
	
	return jr({groupList=>\@groupList});
}

$p_classGrouping_random =<<EOF;
班级学生随机分组

输入：
	{
		"obj":"classGrouping",
		"act":"random",
		"groupsNumber":7,
		"teacherCode":"AA001009",
		"intervalDays":10
	}
输出：
	{
		"groupList":
	}
EOF

#服务端对相应的班级进行随机分组
#{
#	"obj":"classGrouping",
#	"act":"serverRandom"
#}

sub p_classGrouping_serverRandom{
	#return jr() unless assert($gr->{teacherCode},"teacherCode 参数少了","teacherCode","teacherCode 参数少了");

	#Timed task
	my $timeCount = time();
	my $endTime = $timeCount - ($timeCount % 100);
	
	my @timedTaskList = mdb()->get_collection("timedTask")->find()->all();
	foreach my $item(@timedTaskList){
		if($item->{status} ne "开始"){
			next;
		}
		
		my $itemTime = $item->{startTime} - ($item->{startTime} % 100);
		#$itemTime = $endTime - $itemTime;
		my $days = int(($endTime - $itemTime)/3600/24);
		if($days % $item->{timeInterval} == 0){
			my $group = mdb()->get_collection("classGroup")->find_one({teacherCode=>$item->{teacherCode}});
			
			if(!$group){
				return jr() unless assert(0, "分组不存在", "分组不存在", "分组不存在");
			}
		
			my $groupCount = $item->{groupsNumber};
			$group->{groupList} = ();
			$group->{otherList} = ();
			
			my @personList = mdb()->get_collection("person")->find({teacherCode=>$item->{teacherCode}})->all();
			my $total = @personList;
			my $totalTmp = $total;
			my $grouptotal = $total / $groupCount;
			
			my $groupNameHeard = "小组";
			for(my $index = 1; $index <= $groupCount; $index = $index + 1){
				my $groupItem;
				$groupItem->{groupName} = $index.$groupNameHeard;
				$groupItem->{index} = $index;
				for(my $groupCount = 1; $groupCount <= $grouptotal; $groupCount = $groupCount + 1){
					my $randCount = int(rand($total));
					my $student = {
						studentId => @personList[$randCount]->{_id},
						studentName => @personList[$randCount]->{name},
						avatar_fid => @personList[$randCount]->{avatar_fid},
					};
					${$groupItem->{studentList}}{$student->{studentId}} = $student;
					#push @{$groupItem->{studentList}}, $student;
					splice(@personList, $randCount, 1);
					$total = $total - 1;
				}
				
				${$group->{groupList}}{$groupItem->{groupName}} = $groupItem;
				#push @{$group->{groupList}}, $groupItem;
			}
			
			my $remainingCount = $totalTmp % $groupCount;
			
			my @groupNameList = keys %{$group->{groupList}};
			for(my $index = 0; $index < $remainingCount; $index = $index + 1){
				my $randCount = int(rand($total));
				my $student = {
					studentId => @personList[$randCount]->{_id},
					studentName => @personList[$randCount]->{name},
					avatar_fid => @personList[$randCount]->{avatar_fid},
				};
				
				${${$group->{groupList}}{$groupNameList[$index]}->{studentList}}{$student->{studentId}} = $student;
				#push @{$group->{groupList}[$index]->{studentList}}, $student;
				splice(@personList, $randCount, 1);
				
				my $personCount = @personList;
				if($personCount <= 0){
					last;
				}
			}
			
			$group->{updateTime} = time();
			obj_write($group);
			#return jr({group=>$group});
		}
	}
}

sub p_teacherInfo_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}

	my $name = $pref->{name};
	#if($pref->{display_name} eq $pref->{login_name}){
	#	$name = "";
	#}
	
	my $sex = $pref->{sex};
	$sex = "" unless $sex;
	
    return jr({avatar_fid=>$pref->{avatar_fid}, name=>$name, sex=>$sex, account=>$pref->{login_name}, school=>$pref->{school}});
}

$p_teacherInfo_get =<<EOF;
教师端获取用户信息

输入：
	{
		"obj":"teacherInfo",
		"act":"get"
	}
输入：
	{
		"avatar_fid":"",
		"name":"",
		"sex":"",
		"account":""
	}
EOF

sub p_avatar_modify{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}

	$pref->{avatar_fid} = $gr->{avatar_fid};
	obj_write($pref);
	
	if($pref->{position} eq "student"){
		#学生端需要修改对应作业的头像
		my @homeworkList = mdb()->get_collection("homeworkShare")->find({studentId=>$gs->{pid}})->all();
		
		foreach my $homeworkListItem (@homeworkList){
			$homeworkListItem->{avatarFid} = $gr->{avatar_fid};
			obj_write($homeworkListItem);
		}
	}
	
	#需要修改对应点赞的头像
	my @praiseList = mdb()->get_collection("praise")->find({praiseId=>$gs->{pid}})->all();
	
	foreach my $praiseItem (@praiseList){
		$praiseItem->{praiseFid} = $gr->{avatar_fid};
		obj_write($praiseItem);
	}
	
	#需要修改对应评论的头像
	my @commentList = mdb()->get_collection("comment")->find({commentId=>$gs->{pid}})->all();
	
	foreach my $commentItem (@commentList){
		$commentItem->{commentFid} = $gr->{avatar_fid};
		obj_write($commentItem);
	}
	
    return jr();
}

$p_avatar_modify =<<EOF;
修改头像

输入：
	{
		"obj":"avatar",
		"act":"modify",
		"avatar_fid":""
	}
EOF

sub p_books_favourite{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{favourite}, "favourite 参数少了", "favourite", "favourite 参数少了");
	return jr() unless assert($gr->{booksId}, "booksId 参数少了", "booksId", "booksId 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "只有教师才能收藏和取消收藏", "只有教师才能收藏和取消收藏", "只有教师才能收藏和取消收藏");
	}

	if($gr->{favourite} eq "是"){
		my $books = mdb()->get_collection("books")->find_one({_id=>$gr->{booksId}});
		if(!$books){
			return assert(0,"课本资源不存在","not found","课本资源不存在");
		}
	
		if($books->{status} ne "上架"){	
			return jr() unless assert(0,"该课本已下架","该课本已下架","该课本已下架");
		}
		
		my $favourite = {
			_id => obj_id(),
			type => "favourite",
			teacherId => $pref->{_id},
			booksId => $gr->{booksId},
			bookName => $books->{name},
			bookFid => $books->{bookFid},
			grade => $books->{grade},
			introduction => $books->{introduction},
			details => $books->{details},
			guidePrice => $books->{guidePrice},
			basePrice => $books->{basePrice},
			category => $books->{category},
			favouriteTime => time(),
		};
	
		obj_write($favourite);
	}else{
		my $favourite = mdb()->get_collection("favourite")->find_one({teacherId=>$pref->{_id}, booksId=>$gr->{booksId}});
		
		if(!$favourite){
			return jr() unless assert(0, "教师未收藏该资源", "教师未收藏该资源", "教师未收藏该资源");
		}
		#mdb()->get_collection("favourite")->remove({_id=>$favourite->{_id}});
		obj_delete("favourite", $favourite->{_id});
	}

	return jr();
}

$p_books_favourite =<<EOF;
教师端收藏课程或取消收藏

输入：
	{
		"obj":"books",
		"act":"favourite",
		"favourite":"",					(是->收藏,否->取消收藏)
		"booksId":""
	}
EOF

sub p_favouriteBooks_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");

	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "不是教师,暂无收藏功能", "不是教师,暂无收藏功能", "不是教师,暂无收藏功能");
	}
	
	my @favourite = mdb()->get_collection("favourite")->find({teacherId=>$pref->{_id}})->all();
	
	return jr({booksList=>\@favourite});
}

$p_favouriteBooks_get =<<EOF;
获取教师端收藏课程

输入：
	{
		"obj":"favouriteBooks",
		"act":"get"
	}
输出：
	{
		"booksList":
	}
EOF

sub p_homework_praise{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{homeworkId}, "homeworkId 参数少了", "homeworkId", "homeworkId 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	my $position = "";
	if($pref->{position} eq "student"){
		if($pref->{isParent} ne "是"){
			return jr() unless assert(0, "只有家长才能点赞", "只有家长才能点赞", "只有家长才能点赞");
		}
		$position = "parent";
	}elsif($pref->{position} eq "teacher"){
		return jr() unless assert(0, "只有教师才能点赞", "只有教师才能点赞", "只有教师才能点赞");
		$position = "teacher";
	}


	my $homeworkShare = mdb()->get_collection("homeworkShare")->find_one({_id=>$gr->{homeworkId}});
	if(!$homeworkShare){
		return jr() unless assert(0, "作业不存在", "作业不存在", "作业不存在");
	}

	my $praise = {
		_id => obj_id(),
		type => "praise",
		studentId => $homeworkShare->{studentId},
		homeworkId => $homeworkShare->{_id},
		praiseId => $pref->{_id},
		praiseFid => $pref->{avatar_fid},
		position => $position,
		praiseTime => time(),
	};
	
	obj_write($praise);
	return jr();
}

$p_homework_praise =<<EOF;
作业点赞

输入：
	{
		"obj":"homework",
		"act":"praise",
		"homeworkId":""
	}
EOF

sub p_homework_comment{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{homeworkId}, "homeworkId 参数少了", "homeworkId", "homeworkId 参数少了");
	return jr() unless assert($gr->{textContent}, "textContent 参数少了", "textContent", "textContent 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	my $position = "";
	if($pref->{position} eq "student"){
		if($pref->{isParent} ne "是"){
			return jr() unless assert(0, "只有家长才能评论", "只有家长才能评论", "只有家长才能评论");
		}
		$position = "parent";
	}elsif($pref->{position} eq "teacher"){
		return jr() unless assert(0, "只有教师才能评论", "只有教师才能评论", "只有教师才能评论");
		$position = "teacher";
	}

	my $homeworkShare = mdb()->get_collection("homeworkShare")->find_one({_id=>$gr->{homeworkId}});
	if(!$homeworkShare){
		return jr() unless assert(0, "作业不存在", "作业不存在", "作业不存在");
	}

	my $comment = {
		_id => obj_id(),
		type => "comment",
		studentId => $homeworkShare->{studentId},
		homeworkId => $homeworkShare->{_id},
		commentId => $pref->{_id},
		commentFid => $pref->{avatar_fid},
		position => $position,
		textContent => $gr->{textContent},
		praiseTime => time(),
	};
	
	obj_write($comment);
	return jr();
}

$p_homework_comment =<<EOF;
作业评论

输入：
	{
		"obj":"homework",
		"act":"comment",
		"homeworkId":"",
		"textContent":""
	}
EOF

sub p_classAnnouncement_add{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{textContent}, "textContent 参数少了", "textContent", "textContent 参数少了");
	return jr() unless assert($gr->{teacherCode}, "teacherCode 参数少了", "teacherCode", "teacherCode 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "只有教师才能添加公告", "只有教师才能添加公告", "只有教师才能添加公告");
	}

	my $currentTime = time();
	my $homework = mdb()->get_collection("homework")->find_one({teacherCode=>$gr->{teacherCode}, startTime =>{'$lt'=>$currentTime}, finishTime =>{'$gt'=>$currentTime}});
	
	my $classAnnouncement = {
		_id => obj_id(),
		type => "classAnnouncement",
		teacherId => $pref->{_id},
		teacherCode => $gr->{teacherCode},
		textContent => $gr->{textContent},
		booksId => $homework->{booksId},
		bookName => $homework->{bookName},
		chapterId => $homework->{chapterId},
		chapterName => $homework->{chapterName},
		createTime => time(),
	};
	
	obj_write($classAnnouncement);
	
	my @studentList = mdb()->get_collection("person")->find({position=>"student", teacherCode=>$gr->{teacherCode}})->all();
	
	my $message = {
		obj => "classAnnouncement",
		act => "get",
		classAnnouncement => $classAnnouncement,
	};
	
	foreach my $student (@studentList){
		sendto_pid($gr->{server}, $student->{_id}, $message);
	}
	return jr();
}

$p_classAnnouncement_add =<<EOF;
添加班级公告

输入：
	{
		"obj":"classAnnouncement",
		"act":"add",
		"teacherCode":"",
		"textContent":""
	}
EOF

sub p_classAnnouncementList_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode}, "teacherCode 参数少了", "teacherCode", "teacherCode 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "只有教师才能获取往期公告", "只有教师才能获取往期公告", "只有教师才能获取往期公告");
	}

	my @classAnnouncementList = mdb()->get_collection("classAnnouncement")->find({teacherCode=>$gr->{teacherCode}})->sort({"createTime"=>-1})->all();
	
	return jr({classAnnouncementList=>\@classAnnouncementList});
}

$p_classAnnouncementList_get =<<EOF;
教师端获取班级公告列表

输入：
	{
		"obj":"classAnnouncementList",
		"act":"get",
		"teacherCode":""
	}
输出：
	{
		"classAnnouncementList":[]
	}
EOF

sub p_guideReading_statistics{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode}, "teacherCode 参数少了", "teacherCode", "teacherCode 参数少了");
	return jr() unless assert($gr->{chapterID}, "chapterID 参数少了", "chapterID", "chapterID 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "暂无权限获取", "暂无权限获取", "暂无权限获取");
	}

	my @finishList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, guideReadingState=>"已完成", chapterID => $gr->{chapterID}})->all();
	
	my @allList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, chapterID => $gr->{chapterID}})->all();
	#my @undoneList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, guideReadingScore=>"未完成", chapterID => $gr->{chapterID}})->all();
	
	my $finishCount = @finishList;
	my $allCount = @allList;
	my $undoneCount = $allCount - $finishCount;
	
	return jr({finishCount=>$finishCount, undoneCount=>$undoneCount});
}

$p_guideReading_statistics =<<EOF;
教师统计导读人数

输入：
	{
		"obj":"guideReading",
		"act":"statistics",
		"teacherCode":"",
		"chapterID":""
	}
输出：
	{
		"finishCount":12,			已完成 的人数
		"undoneCount":23			未完成 的人数
	}
EOF

sub p_guideReadingInfo_statistics{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode}, "teacherCode 参数少了", "teacherCode", "teacherCode 参数少了");
	return jr() unless assert($gr->{chapterID}, "chapterID 参数少了", "chapterID", "chapterID 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "暂无权限获取", "暂无权限获取", "暂无权限获取");
	}
	
	my @allList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, chapterID => $gr->{chapterID}, guideReadingState=>"已完成"})->all();
	
	my @finishList = ();
	my @undoneList = ();
	
	foreach my $item (@allList){
		if($item->{guideReadingState} eq "已完成"){
			push @finishList, $item->{studentName};
		}else{
			push @undoneList, $item->{studentName};
		}
	}
	
	return jr({finishList=>\@finishList, undoneList=>\@undoneList});
}

$p_guideReadingInfo_statistics =<<EOF;
教师统计导读详情

输入：
	{
		"obj":"guideReadingInfo",
		"act":"statistics",
		"teacherCode":"",
		"chapterID":""
	}
输出：
	{
		"finishList":[],		已完成
		"undoneList":[]			未完成
	}
EOF

sub p_modelReading_statistics{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode}, "teacherCode 参数少了", "teacherCode", "teacherCode 参数少了");
	return jr() unless assert($gr->{chapterID}, "chapterID 参数少了", "chapterID", "chapterID 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "暂无权限获取", "暂无权限获取", "暂无权限获取");
	}

	my @finishList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, modelReadingState=>"已完成", chapterID => $gr->{chapterID}});
	
	my @allList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, chapterID => $gr->{chapterID}});
	#my @undoneList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, modelReadingState=>"未完成", chapterID => $gr->{chapterID}});
	
	my $finishCount = @finishList;
	my $allCount = @allList;
	my $undoneCount = $allCount - $finishCount;
	
	return jr({finishCount=>$finishCount, undoneCount=>$undoneCount});
}

$p_modelReading_statistics =<<EOF;
教师统计范读人数

输入：
	{
		"obj":"modelReading",
		"act":"statistics",
		"teacherCode":"",
		"chapterID":""
	}
输出：
	{
		"finishCount":12,			已完成 的人数
		"undoneCount":23			未完成 的人数
	}
EOF

sub p_modelReadingInfo_statistics{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode}, "teacherCode 参数少了", "teacherCode", "teacherCode 参数少了");
	return jr() unless assert($gr->{chapterID}, "chapterID 参数少了", "chapterID", "chapterID 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "暂无权限获取", "暂无权限获取", "暂无权限获取");
	}
	
	my @allList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, chapterID => $gr->{chapterID}, modelReadingState=>"已完成"})->all();
	
	my @finishList = ();
	my @undoneList = ();
	
	foreach my $item (@allList){
		if($item->{modelReadingState} eq "已完成"){
			push @finishList, $item->{studentName};
		}else{
			push @undoneList, $item->{studentName};
		}
	}
	
	return jr({finishList=>\@finishList, undoneList=>\@undoneList});
}

$p_modelReadingInfo_statistics =<<EOF;
教师统计范读详情

输入：
	{
		"obj":"modelReadingInfo",
		"act":"statistics",
		"teacherCode":"",
		"chapterID":""
	}
输出：
	{
		"finishList":[],		已完成
		"undoneList":[]			未完成
	}
EOF

sub p_readingAloud_statistics{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode}, "teacherCode 参数少了", "teacherCode", "teacherCode 参数少了");
	return jr() unless assert($gr->{chapterID}, "chapterID 参数少了", "chapterID", "chapterID 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "暂无权限获取", "暂无权限获取", "暂无权限获取");
	}

	#my @finishList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, readingAloudScore=>5, chapterID => $gr->{chapterID}});
	#my @undoneList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, readingAloudScore=>4, chapterID => $gr->{chapterID}});
	#my @finishList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, readingAloudScore=>3, chapterID => $gr->{chapterID}});
	#my @undoneList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, chapterID => $gr->{chapterID}});
	
	my @finishList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, readingAloudState=>"已完成", chapterID => $gr->{chapterID}});
	
	my @allList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, chapterID => $gr->{chapterID}});
	#modelReadingScore
	
	my $finishCount = @finishList;
	my $allCount = @allList;
	my $undoneCount = $allCount - $finishCount;
	
	my $totalSorce = 0;
	foreach my $item(@finishList){
		$totalSorce += $item->{readingAloudTotalSorce};
	}
	
	my $aveSorce = $totalSorce / $allCount;
	
	return jr({finishCount=>$finishCount, undoneCount=>$undoneCount, aveSorce=>$aveSorce});
}

$p_readingAloud_statistics =<<EOF;
教师统计朗读人数

输入：
	{
		"obj":"readingAloud",
		"act":"statistics",
		"teacherCode":"",
		"chapterID":""
	}
输出：
	{
		"finishCount":12,			已完成 的人数
		"undoneCount":23,			未完成 的人数
		"aveSorce":12				平均成绩
	}
EOF

sub p_readingAloudInfo_statistics{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode}, "teacherCode 参数少了", "teacherCode", "teacherCode 参数少了");
	return jr() unless assert($gr->{chapterID}, "chapterID 参数少了", "chapterID", "chapterID 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "暂无权限获取", "暂无权限获取", "暂无权限获取");
	}
	
	my @allList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, chapterID => $gr->{chapterID}, readingAloudState=>"已完成"})->all();
	
	my @fiveStarsList = ();
	my @fourStarsList = ();
	my @threeStarsList = ();
	my @LessTwoStarsList = ();
	
	foreach my $item (@allList){
		if($item->{readingAloudTotalSorce} == 5){
			push @fiveStarsList, $item->{studentName};
		}elsif($item->{readingAloudTotalSorce} == 4){
			push @fourStarsList, $item->{studentName};
		}elsif($item->{readingAloudTotalSorce} == 3){
			push @threeStarsList, $item->{studentName};
		}else{
			push @LessTwoStarsList, $item->{studentName};
		}
	}
	
	return jr({fiveStarsList=>\@fiveStarsList, fourStarsList=>\@fourStarsList, threeStarsList=>\@threeStarsList, LessTwoStarsList=>\@LessTwoStarsList});
}

$p_readingAloudInfo_statistics =<<EOF;
教师统计朗读详情

输入：
	{
		"obj":"readingAloudInfo",
		"act":"statistics",
		"teacherCode":"",
		"chapterID":""
	}
输出：
	{
		"fiveStarsList":[],				五颗星
		"fourStarsList":[],				四颗星
		"threeStarsList":[],			三颗星
		"LessTwoStarsList":[]			小于两颗星
	}
EOF

sub p_silentReading_statistics{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode}, "teacherCode 参数少了", "teacherCode", "teacherCode 参数少了");
	return jr() unless assert($gr->{chapterID}, "chapterID 参数少了", "chapterID", "chapterID 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "暂无权限获取", "暂无权限获取", "暂无权限获取");
	}

	#my @excellentList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, silentReadingScore=>"优", chapterID => $gr->{chapterID}});
	#my @goodList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, silentReadingScore=>"良", chapterID => $gr->{chapterID}});
	#my @failedList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, silentReadingScore=>"不合格", chapterID => $gr->{chapterID}});
	#my $excellentCount = @excellentList;
	#my $goodCount = @goodList;
	#my $failedCount = @failedList;
	
	my @finishList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, silentReadingState=>"已完成", chapterID => $gr->{chapterID}});
	
	my @allList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, chapterID => $gr->{chapterID}});
	#modelReadingScore
	
	my $finishCount = @finishList;
	my $allCount = @allList;
	my $undoneCount = $allCount - $finishCount;
	
	my $totalSorce = 0;
	foreach my $item(@finishList){
		if($item->{silentReadingTotalSorce} eq "优"){
			$totalSorce += 5;
		}elsif($item->{silentReadingTotalSorce} eq "良"){
			$totalSorce += 2.5;
		}elsif($item->{silentReadingTotalSorce} eq "不合格"){
			$totalSorce += 0;
		}
	}
	
	#计算默读平均成绩
	my $aveSorce = "";
	$totalSorce = $totalSorce / $allCount;
	if($totalSorce < 2){
		$aveSorce = "不合格";
	}elsif($totalSorce  > 3){
		$aveSorce = "优";
	}else{
		$aveSorce = "良";
	}
	
	return jr({finishCount=>$finishCount, undoneCount=>$undoneCount, aveSorce=>$aveSorce});
	#return jr({excellentCount=>$excellentCount, goodCount=>$goodCount, failedCount=>$failedCount});
}

$p_silentReading_statistics =<<EOF;
教师统计默读人数

输入：
	{
		"obj":"silentReading",
		"act":"statistics",
		"teacherCode":"",
		"chapterID":""
	}
输出：
	{
		"finishCount":12,			已完成 的人数
		"undoneCount":23,			未完成 的人数
		"aveSorce":12				平均成绩
	}
EOF

sub p_silentReadingInfo_statistics{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode}, "teacherCode 参数少了", "teacherCode", "teacherCode 参数少了");
	return jr() unless assert($gr->{chapterID}, "chapterID 参数少了", "chapterID", "chapterID 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "暂无权限获取", "暂无权限获取", "暂无权限获取");
	}
	
	my @allList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, chapterID => $gr->{chapterID}, silentReadingState=>"已完成"})->all();
	
	my @excellentList = ();
	my @goodList = ();
	my @passList = ();
	
	foreach my $item (@allList){
		if($item->{silentReadingTotalSorce} eq "优"){
			push @excellentList, $item->{studentName};
		}elsif($item->{silentReadingTotalSorce} eq "良"){
			push @goodList, $item->{studentName};
		}elsif($item->{silentReadingTotalSorce} eq "及格"){
			push @passList, $item->{studentName};
		}
	}
	
	return jr({excellentList=>\@excellentList, goodList=>\@goodList, passList=>\@passList});
}

$p_silentReadingInfo_statistics =<<EOF;
教师统计默读详情

输入：
	{
		"obj":"silentReadingInfo",
		"act":"statistics",
		"teacherCode":"",
		"chapterID":""
	}
输出：
	{
		"excellentList":[],			优
		"goodList":[],				良
		"passList":[],				及格
	}
EOF

sub p_testQuestions_statistics{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode}, "teacherCode 参数少了", "teacherCode", "teacherCode 参数少了");
	return jr() unless assert($gr->{chapterID}, "chapterID 参数少了", "chapterID", "chapterID 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "暂无权限获取", "暂无权限获取", "暂无权限获取");
	}

	#my @excellentList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, testQuestionsScore=>"优", chapterID => $gr->{chapterID}});
	#my @goodList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, testQuestionsScore=>"良", chapterID => $gr->{chapterID}});
	#my @failedList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, testQuestionsScore=>"及格", chapterID => $gr->{chapterID}});
	#my $excellentCount = @excellentList;
	#my $goodCount = @goodList;
	#my $failedCount = @failedList;
	#return jr({excellentCount=>$excellentCount, goodCount=>$goodCount, failedCount=>$failedCount});
	
	my @finishList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, testQuestionsState=>"已完成", chapterID => $gr->{chapterID}});
	
	my @allList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, chapterID => $gr->{chapterID}});
	#modelReadingScore
	
	my $finishCount = @finishList;
	my $allCount = @allList;
	my $undoneCount = $allCount - $finishCount;
	
	my $totalSorce = 0;
	foreach my $item(@finishList){
		if($item->{testQuestionsScore} eq "优"){
			$totalSorce += 5;
		}elsif($item->{testQuestionsScore} eq "良"){
			$totalSorce += 2.5;
		}elsif($item->{testQuestionsScore} eq "及格"){
			$totalSorce += 0;
		}
	}
	
	#计算默读平均成绩
	my $aveSorce = "";
	$totalSorce = $totalSorce / $allCount;
	if($totalSorce < 2){
		$aveSorce = "及格";
	}elsif($totalSorce  > 3){
		$aveSorce = "优";
	}else{
		$aveSorce = "良";
	}
	
	return jr({finishCount=>$finishCount, undoneCount=>$undoneCount, aveSorce=>$aveSorce});
}

$p_testQuestions_statistics =<<EOF;
教师统计章节评测题人数

输入：
	{
		"obj":"testQuestions",
		"act":"statistics",
		"teacherCode":"",
		"chapterID":""
	}
输出：
	{
		"finishCount":12,			已完成 的人数
		"undoneCount":23,			未完成 的人数
		"aveSorce":12				平均成绩
	}
EOF

sub p_testQuestionsInfo_statistics{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode}, "teacherCode 参数少了", "teacherCode", "teacherCode 参数少了");
	return jr() unless assert($gr->{chapterID}, "chapterID 参数少了", "chapterID", "chapterID 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "暂无权限获取", "暂无权限获取", "暂无权限获取");
	}
	
	my @allList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, chapterID => $gr->{chapterID}, testQuestionsState=>"已完成"})->all();
	
	my @excellentList = ();
	my @goodList = ();
	my @passList = ();
	
	foreach my $item (@allList){
		if($item->{silentReadingTotalSorce} eq "优"){
			push @excellentList, $item->{studentName};
		}elsif($item->{silentReadingTotalSorce} eq "良"){
			push @goodList, $item->{studentName};
		}elsif($item->{silentReadingTotalSorce} eq "及格"){
			push @passList, $item->{studentName};
		}
	}
	
	return jr({excellentList=>\@excellentList, goodList=>\@goodList, passList=>\@passList});
}

$p_testQuestionsInfo_statistics =<<EOF;
教师统计章节评测题详情

输入：
	{
		"obj":"testQuestionsInfo",
		"act":"statistics",
		"teacherCode":"",
		"chapterID":""
	}
输出：
	{
		"excellentList":[],			优
		"goodList":[],				良
		"passList":[],				及格
	}
EOF

sub p_scheduleInfo_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode}, "teacherCode 参数少了", "teacherCode", "teacherCode 参数少了");
	return jr() unless assert($gr->{chapterID}, "chapterID 参数少了", "chapterID", "chapterID 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "只有教师才能添加公告", "只有教师才能添加公告", "只有教师才能添加公告");
	}
	
	my @finishList = ();
	my @undoneList = ();
	my @allList = mdb()->get_collection("chapterSchedule")->find({teacherCode=>$gr->{teacherCode}, chapterID => $gr->{chapterID}})->all();
	
	my $typeName = "";
	if($gr->{type} eq "导读"){
		$typeName = "guideReadingState";
	}elsif($gr->{type} eq "范读"){
		$typeName = "modelReadingState";
	}elsif($gr->{type} eq "朗读"){
		$typeName = "readingAloudState";
	}elsif($gr->{type} eq "默读"){
		$typeName = "silentReadingState";
	}elsif($gr->{type} eq "章节评测"){
		$typeName = "testQuestionsState";
	}
	
	foreach my $item (@allList){
		if($item->{$typeName} eq "已完成"){
			push @finishList, $item->{studentName};
		}else{
			push @undoneList, $item->{studentName};
		}
	}

	return jr({finishList=>\@finishList, undoneList=>\@finishList});
}

$p_scheduleInfo_get =<<EOF;
教师统计完成学生

输入：
	{
		"obj":"scheduleInfo",
		"act":"get",
		"teacherCode":"",
		"chapterID":"",
		"type":""		导读/范读/朗读/默读/章节评测
	}
输出：
	{
		"finishList":[			已完成列表
			"张三",
			"李四"
		],
		"undoneList":[			未完成列表
			"张三",
			"李四"
		],
	}
EOF

sub p_previousCourse_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode}, "teacherCode 参数少了", "teacherCode", "teacherCode 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	my $currentTime = time();
	my @homework = mdb()->get_collection("homework")->find({teacherCode=>$gr->{teacherCode}, finishTime =>{'$lt'=>$currentTime}})->sort({"publistTime"=>-1})->all();
	
	my $count = @homework;
	
	if($count == 0){
		return jr() unless assert(0, "暂无课程", "暂无课程", "暂无课程");
	}
	
	#my @homeworkList = mdb()->get_collection("homework")->find({booksId=>$homework->{booksId}})->all();
    #@homeworkList = sort { $a->{pageSpacing} <=> $b->{pageSpacing} } @homeworkList;
	
	foreach my $item(@homework){
		my $books = mdb()->get_collection("books")->find_one({_id=>$item->{booksId}});
		$item->{introduction} = $books->{introduction};
		$item->{bookFid} = $books->{bookFid};
	}
	
	return jr({homeworkList=>\@homework});
}

$p_previousCourse_get =<<EOF;
教师端获取往期课程

输入：
	{
		"obj":"previousCourse",
		"act":"get",
		"teacherCode":""
	}
输入：
	{
		"homeworkList":""
	}
EOF

sub p_previousCourse_search{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{teacherCode}, "teacherCode 参数少了", "teacherCode", "teacherCode 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	my $currentTime = time();
	my @homework = ();
	if(length($gr->{startTime}) and length($gr->{endTime})){
		my $startTime = $gr->{startTime} - 1;
		my $endTime = $gr->{endTime} + 1;
		
		@homework = mdb()->get_collection("homework")->find({teacherCode=>$gr->{teacherCode}, startTime =>{'$gt'=>$startTime}, finishTime =>{'$lt'=>$endTime}})->sort({"publistTime"=>-1})->all();
	}else{
		@homework = mdb()->get_collection("homework")->find({teacherCode=>$gr->{teacherCode}})->sort({"publistTime"=>-1})->all();
	}
	
	foreach my $item(@homework){
		my $books = mdb()->get_collection("books")->find_one({_id=>$item->{booksId}});
		$item->{introduction} = $books->{introduction};
		$item->{bookFid} = $books->{bookFid};
	}
	
	return jr({homeworkList=>\@homework});
}

$p_previousCourse_search =<<EOF;
教师端搜索往期课程

输入：
	{
		"obj":"previousCourse",
		"act":"search",
		"teacherCode":"",
		"startTime":123,
		"endTime":123
	}
输入：
	{
		"homeworkList":""
	}
EOF

sub p_teacherClasses_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "只有教师才能获取班级列表", "只有教师才能获取班级列表", "只有教师才能获取班级列表");
	}
	
	my @classListTmp = mdb()->get_collection("classMember")->find({teacherId=>$pref->{_id}})->all();
	
	my $count = @classListTmp;
	if($count == 0){
		return jr() unless assert(0, "教师暂无管理的班级", "教师暂无管理的班级", "教师暂无管理的班级");
	}
	
	#my @classListTmp = @classList;
	my @grades = ();
	while(scalar(@classListTmp)){
		my $gradeId = $classListTmp[0]->{gradeId};
		my $gradesItem->{grade} = $classListTmp[0]->{grade};
		
		my @classList = ();
		#foreach my $item (@classListTmp){
		for(my $index = 0;$index < $count; $index += 1){
			if($classListTmp[$index]->{gradeId} eq $gradeId){
				my $class = {
					class => $classListTmp[$index]->{class},
					classId => $classListTmp[$index]->{_id},
					teacherCode => $classListTmp[$index]->{teacherCode},
				};
				
				push @{$gradesItem->{classes}}, $class;
				
				#splice(@classList, $index, 1);
			}
			else{
				push @classList, $classListTmp[$index];
			}
		}
		
		push @grades, $gradesItem;
		@classListTmp = @classList;
	}

	return jr({grades=>\@grades});
}

$p_teacherClasses_get =<<EOF;
教师端获取教师管理的班级和年级

输入：
	{
		"obj":"teacherClasses",
		"act":"get"
	}
输入：
	{
		"grades":[
			{
				"grade": "二年级",
				"classes":[
					{
						"class":"一班",
						"classId":"123",
						"teacherCode":""
					},
					{
						"class":"五班",
						"classId":"333",
						"teacherCode":""
					}
				]
			}
		]
	}
EOF

sub p_guideReadingCourseDetails_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{booksId}, "booksId 参数少了", "booksId 参数少了", "booksId 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "teacher"){
		return jr() unless assert(0, "不是教师,无法获取", "不是教师,无法获取", "不是教师,无法获取");
	}
	
	my @homeworkList = mdb()->get_collection("homework")->find({teacherCode=>$pref->{teacherCode}, booksId=>$gr->{booksId}, finishTime =>{'$lt'=>$currentTime}, publishState=>"已完成"})->sort({"publistTime"=>-1})->all();
	
	my $count = @homeworkList;
	
	if($count == 0){
		return jr() unless assert(0, "暂无课程", "暂无课程", "暂无课程");
	}
	
	return jr({homeworkList=>\@homeworkList});
}

$p_guideReadingCourseDetails_get =<<EOF;
获取导读版课程详情

输入：
	{
		"obj":"guideReadingCourseDetails",
		"act":"get",
		"booksId":"xxxxxxx"
	}
输入：
	{
		"homeworkList":""
	}
EOF

#end 教师端

sub p_wechatOpenid_get{
	# do not use my !! causing problems!
	return jr() unless assert($gr->{code},"code 参数少了","code","code 参数少了");
	
	my $jscode = $gr->{code};
	my $secret = "cdb3da44af808b8e5125ae57df4fe29e";
	my $appId = "wxcd3f5be2d3b476ab";
	
	my $session_key_api = "https://api.weixin.qq.com/sns/jscode2session?appid=".$appId."&secret=".$secret."&js_code=".$jscode."&grant_type=authorization_code";

	my $json = JSON->new();
    	my $ua = LWP::UserAgent->new();
    	my $req = HTTP::Request->new('GET', $session_key_api); 
    	my $response = $ua->request($req);
    	my $ret;
	if ($response->message ne "OK" && $response->is_success ne "1") { #出错,或者timeout了
		$ret->{status} = "time out";
	} else {
		$ret = $json->decode($response->decoded_content());
	}
	
	my $openid = $ret->{openid};
    return jr({response => $ret});
}

$p_wechatOpenid_get =<<EOF;
微信登录获取openid

输入：
	{
		"obj":"wechatOpenid",
		"act":"get",
		"code":"xxxxxxxx",
	}
输出：
	{
		sess: "", 
		io: "o", 
		obj: "loginInfo", 
		act: "get", 
		perf: 0.106459140777588, 
		perf_sk: null, 
		response:
		{
			openid: "oo5Wt4ulGiVvyZBOMn66qYpo98Us", 
			session_key: "ZuGxsmYaHyV3C9/JSmJyFQ=="
		}
	}
EOF

sub p_orderList_get{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	
	my $pref = obj_read("person", $gs->{pid});
	if(!$pref){
		return jr() unless assert(0, "用户不存在", "用户不存在", "用户不存在");
	}
	
	if($pref->{position} ne "student"){
		return jr() unless assert(0, "用户不是学生,无法获取", "用户不是学生,无法获取", "用户不是学生,无法获取");
	}
	
	my @orderList = mdb()->get_collection("order")->find({personId=>$gs->{pid}, Order_Status=>"已完成"})->sort({"createTime"=>-1})->all();
	
	return jr({orderList=>\@orderList});
}

$p_orderList_get =<<EOF;
获取订单列表

输入：
	{
		"obj":"orderList",
		"act":"get"
	}
输出：
	{
		"orderList":[]
	}
EOF

sub p_order_finish {
	#my $response = $_[0];
	my $PaymentBill = obj_read("PaymentBill", $gr->{PaymentBillId});
	if(!$PaymentBill){
		return jr({ustr => "账单不存在", uerr => "账单id不存在"});
	}
	
	my $order = obj_read("order", $PaymentBill->{orderId});
	
	if ($gr->{pay_result} ne "success") {#支付失败
		$PaymentBill->{Order_Status} = "支付失败";
		obj_write($PaymentBill);
		
		if($order){
			$order->{Order_Status} = "支付失败";
			obj_write($order);
		}
	
		return jr({status=>"failed", order_info=>$PaymentBill});
	}
	
	#if ($PaymentBill->{client_type} eq "app") {#APP支付需推送
	#	my $app_msg;
	#	$app_msg->{obj} = "order";
	#	$app_msg->{act} = "finish";
	#	$app_msg->{order_id} = $PaymentBill->{order_id};
	#	$app_msg->{money} = $PaymentBill->{rmb};
	#	$app_msg->{pay_result} = $gr->{pay_result};
	#	$app_msg->{call} = "recharge_finish";
	#	
	#	my $ret = sendto_pid($gr->{server}, $PaymentBill->{personId}, $app_msg);
	#}
	
	
	#支付完成,账单状态更改为已完成,后面查找的列表是订单列表。
	$PaymentBill->{Order_Status} = "已完成";
	
	if($order){
		$order->{Order_Status} = "已完成";
		p_statistics_book($PaymentBill->{orderId});#用于统计销售数据
	}
	obj_write($order);
	obj_write($PaymentBill);
	return jr();
}

sub p_PaymentBill_generate{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{booksId},"booksId 参数少了","booksId","booksId 参数少了");
	return jr() unless assert($gr->{category},"category 参数少了","category","category 参数少了");
	
	my $pref = obj_read("person", $gs->{pid});
	
	my $CurrentTime = time();
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($CurrentTime);
	$year += 1900;
	$mon += 1;
	
	my $strTime = $year.$mon.$mday.$hour.$min.$sec;
	my $num = int(rand(1000000));
	my $PaymentBillId = $strTime.$num;
	
	my $books = mdb()->get_collection("books")->find_one({_id=>$gr->{booksId}});
	if(!$books){
		return jr() unless assert(0,"资源不存在","资源不存在","资源不存在");
	}
	
	if($books->{status} ne "上架"){	
		return jr() unless assert(0,"该课本已下架","该课本已下架","该课本已下架");
	}
		
	my $price = 0;
	if($gr->{category} eq "基础版"){
		$price = $books->{basePrice};
	}elsif($gr->{category} eq "导读版"){
		$price = $books->{guidePrice};
	}
	
	my $PaymentBill = {
		_id => obj_id(),
		type => 'PaymentBill',
		personId => $pref->{_id},
		display_name => $pref->{name},
		orderAmount => 0.01,#$price,
		Order_Status => "待付款",
		Order_Number => $PaymentBillId,
		pay_type => $gr->{paymentTypes},
		client_type => "app",
		createTime => $CurrentTime,
	};
	
	my $order = {
		_id => obj_id(),
		type => 'order',
		personId => $pref->{_id},
		display_name => $pref->{name},
		booksId => $gr->{booksId},
		bookName => $books->{name},
		bookFid => $books->{bookFid},
		category => $gr->{category},
		price => 0.01,#$price,
		Order_Status => "待付款",
		PaymentBillId => $PaymentBillId,
		pay_type => $gr->{paymentTypes},
		createTime => $CurrentTime,
	};
	
	$PaymentBill->{orderId} = $order->{_id};

	obj_write($PaymentBill);
	obj_write($order);

	my $pay_info = PaymentBill_pay($PaymentBill, $gr->{paymentTypes}, $gs->{pid}, "");
	return jr({pay_info=>$pay_info});
}

$p_PaymentBill_generate =<<EOF;
生成支付账单

输入：
	{
		"obj":"PaymentBill",
		"act":"generate",
		"booksId":"xxxxxxxxxxx",			booksId
		"category":"",
		"paymentTypes":""					alipay/wechat
	}
输出：
	
EOF

sub PaymentBill_pay {
	my $count = scalar(@_);
	if($count != 4){
		return jr({ustr => "支付参数参数错误", uerr => "支付参数参数错误"});
	}
	my ($PaymentBill, $payType, $person_id, $openid) = @_;
	#my $PaymentBill = $_[0];
	#my $payType = $_[1];
	#my $person_id = $gr->{person_id}
	#my $openid

	
	my @pay_types = ("wechat", "alipay"); #, "apple", "official");
	if ( !(grep {$_ eq $payType} @pay_types) ) {
		return jr({status=>"failed"}) unless assert(0, "pay_type unsupported", "ERR_PAY_TYPE_INVALID", "该支付类型不支持哦");
	}

	$is_app = "true";
	#my $clientType = $gr->{client_type} unless "app";
	my $clientType = "app";
	if ($clientType eq "wxa") {#小程序支付必须传用户openid
		return jr({status=>"failed"}) unless assert(length($openid), "openid not set", "ERR_OPENID_MISSING", "用户openid丢失");
		$is_app = "false";
	}
	my $person = obj_read("person", $person_id, 1);
	return jr({status=>"failed"}) unless assert($person, "person not exists", "ERR_PERSON_NOT_EXISTS", "用户信息丢失");
	
	$PaymentBill->{buy_type} = "service_fee";
	if (length($openid)) {
		$PaymentBill->{openid} = $openid;
	}
	obj_write($PaymentBill);
	
	my $prep = {};
	my $prepay_info = {};
	my $prepay_info_request = {};
	
	my $pay_info = {};
	#my $token_id = "";
	if ($payType eq "wechat") {
		$prep = wechat_get_prepay_id($PaymentBill);
		$prepay_info_request = $prep->{request};
		$prepay_info = $prep->{response};
	}elsif ($payType eq "alipay") {
		$prepay_info = alipay_get_prepay_id($PaymentBill);
	}
	
	my $now_t = time();
	
	if ($payType eq "wechat") {#微信支付
		if ($prepay_info->{return_code} ne "SUCCESS" || $prepay_info->{result_code} ne "SUCCESS") {
			obj_write($PaymentBill);
			
			#return jr({status=>"failed", wx_msg=>$prepay_info->{message}}) unless assert(0, "get prepayid failed", "ERR_GET_PREPAYID", "获取预支付订单信息失败");
			return jr({status=>"failed", prepay_info_request=> $prepay_info_request, prepay_info_ret =>$prepay_info}) 
			unless assert(0, "get prepayid failed", "ERR_GET_PREPAYID", "获取预支付订单信息失败");
		}
		$PaymentBill->{prepay_id} = $prepay_info->{prepay_id};
		my $ret = set_wechat_paysign_params($prepay_info, $is_app, $now_t);
		$pay_info = $ret->{pay_info};
		$pay_info->{package} = $ret->{temp}->{package};
		$pay_info->{paySign} = md5_sign($ret->{temp}, $ret->{trade_type});
		$pay_info->{pay_money} = $PaymentBill->{orderAmount};
		
	} else {#支付宝
		$PaymentBill->{prepay_id} = $prepay_info->{sign_str};
		#$token_id = $prepay_info->{sign_str};
		$pay_info->{sign_str} = $prepay_info->{sign_str};
		
		#$pay_info->{sign} = $prepay_info->{sign};
		#$pay_info->{key} = $prepay_info->{key};
		#$pay_info->{content} = $prepay_info->{content};
		#$pay_info->{home} = $prepay_info->{home};
	}
	$PaymentBill->{ut} = $now_t;
	#$PaymentBill->{Order_Status} = "prepay";
	# 把 预支付信息也记住在订单里面
	$PaymentBill->{prepay_info} = $prepay_info;
	obj_write($PaymentBill);
	
	return {pay_info=>$pay_info};
	
	
	
	
	
	
	
	
	
	
	my $prep = wechat_get_prepay_id($PaymentBill);
	my $prepay_info_request = $prep->{request};
	my $prepay_info = $prep->{response};

	if ($prepay_info->{return_code} ne "SUCCESS" || $prepay_info->{result_code} ne "SUCCESS") {
		obj_write($PaymentBill);
		return jr({status=>"failed", prepay_info_request=> $prepay_info_request, prepay_info_ret =>$prepay_info}) 
			unless assert(0, "get prepayid failed", "ERR_GET_PREPAYID", "获取预支付订单信息失败");
	}

	# 把 预支付信息也记住在订单里面
	$PaymentBill->{prepay_info} = $prepay_info;

	# false 说明是公众号,小程序,不是APP
	my $now = time();
	my $ret = set_wechat_paysign_params($prepay_info, "false", $now);

	# 给客户端调用的参数信息
	my $pay_info = $ret->{pay_info};
	$pay_info->{appId} = $prepay_info->{appid};
	$pay_info->{package} = $ret->{temp}->{package};
	$pay_info->{paySign} = md5_sign($ret->{temp}, $ret->{trade_type});
	$pay_info->{orderAmount} = $PaymentBill->{orderAmount};

	$PaymentBill->{is_app} = "false"; # APP 还是公众号
	$PaymentBill->{ut} = $now;
	$PaymentBill->{pay_status} = "prepay"; # 当前是 prepay 状态

	obj_write($PaymentBill);

	#my $ret = {pay_info=>$pay_info, PaymentBill=>$PaymentBill, prepay_info_request=> $prepay_info_request, prepay_info_ret =>$prepay_info};
	return $pay_info;
	#return jr({pay_info=>$pay_info, PaymentBill=>$PaymentBill, prepay_info_request=> $prepay_info_request, prepay_info_ret =>$prepay_info});
}

sub nonce_str {
	#prel this pointer $self means myself
	my $len = 32;
	my @a       = ( "A" .. "Z", 0 .. 9 );
	my $max = scalar @a - 1;
	return join( "", map { $a[ int( rand($max) ) ] } 1 .. $len );
}

# 微信支付接口签名校验工具
# https://pay.weixin.qq.com/wiki/doc/api/jsapi.php?chapter=20_1
# 如果验证没错,还是报签名错误,看看 商户Key mch_id对应的appkey 是不是对的
sub md5_sign {
	my ($params, $trade_type)  = @_;
	my $app_key = $WECHAT_CONFIG->{user}->{appkey};
	if ($trade_type eq "APP") {
		$app_key = $WECHAT_CONFIG->{user_app}->{appkey};
	}
	my $params_sign = {};
	foreach ( keys %$params ) {
		next if $_ eq 'sign';
		next unless defined $params->{$_};
		Encode::_utf8_off( $params->{$_} );
		$params_sign->{$_} = $params->{$_};
	}

	my $sign_string = join( '&',
			map { sprintf( '%s=%s', $_, $params_sign->{$_} ) }
			sort { $a cmp $b } keys %$params_sign );
		
	$sign_string .= sprintf( '&key=%s', $app_key );
	
	return uc md5_hex $sign_string;
}

sub create_xml_data {
	my $params = $_[0];
	my $xml     = '<xml>';
	foreach ( keys %$params ) {
		if ( $params->{$_} and $params->{$_} !~ /^\d+$/ ) {
			$xml .= sprintf( '<%s><![CDATA[%s]]></%s>', $_, $params->{$_}, $_ );
		}
		else {
			$xml .= sprintf( '<%s>%s</%s>', $_, $params->{$_}, $_ );
		}
	}
	$xml .= '</xml>';
	return $xml;
}

sub valid_response {
	my $params  = $_[0];
	my $sign    = delete $params->{sign}; 
	my $sign_me = md5_sign($params, $params->{trade_type});
	
	if ($sign and $sign eq $sign_me) {
		$params->{sign} = $sign;
		return 1;
	} else {
		return 0; 
	}
}

sub parse_response_with_xml_format {
	my $content = $_[0];
	my $result  = XMLin($content);
	return $result;

	if ($result->{result_code} eq "SUCCESS" ) {
		$sign_gal =$result->{sign};

		if ($result->{return_code} eq "SUCCESS") {
			return $result if valid_response($result);
			#$result->{errmsg}=$result->{err_msg};
			return $result;
		} 
		else {
			#return $result->{errmsg}=$result->{err_msg};
			return $result; 
		}
	}
}

sub formateTime { 
	my $time1 = $_[0];
	
	my ($sec,$min,$hour,$day,$month,$year,$wday,$yday,$isdst) = localtime($time1);
	$year = $year + 1900;
	$month = $month + 1;
	
	my $format = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year, $month, $day, $hour, $min, $sec); #2016-08-25 20:26:31
	return "$format";
}

sub wechat_get_prepay_id {
	my $order_info = $_[0];

	my $PayInfo;
	my $key_wd = "user";
	if (length($order_info->{openid}) == 0) { #APP支付
		$key_wd = "user_app";
	}
	$PayInfo->{mch_id} = $WECHAT_CONFIG->{$key_wd}->{mch_id};
	$PayInfo->{nonce_str} = nonce_str();
	$PayInfo->{sign_type} = "MD5";
	if ($order_info->{buy_type} eq "late_fee") {
		$PayInfo->{body} = "支付违约金";
	} elsif ($order_info->{buy_type} eq "service_fee") {
		$PayInfo->{body} = "支付订单费用";
	} elsif ($order_info->{buy_type} eq "recharge") {
		$PayInfo->{body} = "账户充值";
	} elsif ($order_info->{buy_type} eq "buyBooks") {
		$PayInfo->{body} = "支付测试 TEST";
	}

	$PayInfo->{appid} = $WECHAT_CONFIG->{$key_wd}->{appid}; #支付的小程序appid
	$PayInfo->{out_trade_no} = $order_info->{_id};
	if (length($order_info->{my_out_trade_no})) {
		$PayInfo->{out_trade_no} = $order_info->{my_out_trade_no};
	}
	$PayInfo->{spbill_create_ip} = "127.0.0.1";#用户端实际ip
	$PayInfo->{total_fee} = POSIX::ceil(100 * $order_info->{orderAmount});

	$PayInfo->{notify_url} = $WECHAT_CONFIG->{notify_url};
	$PayInfo->{trade_type} = $WECHAT_CONFIG->{$key_wd}->{trade_type};
	if (length($order_info->{openid})) { #小程序支付
		$PayInfo->{openid} = $order_info->{openid};
	}
	
	$PayInfo->{attach} = lc(__PACKAGE__); #添加 工程名字
	$PayInfo->{sign} = md5_sign($PayInfo, $PayInfo->{trade_type});

	#转成xml格式
	my $request_xml = create_xml_data($PayInfo);
	syslog("req-xml:".$request_xml); #."\nreq-json:".Dumper($PayInfo));
	
	#POST请求 
	my $header = HTTP::Headers->new( Content_Type => 'text/xml; charset=utf8', );
	my $http_request = HTTP::Request->new(POST => "https://api.mch.weixin.qq.com/pay/unifiedorder", $header, $request_xml);

	#处理响应
	my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0, SSL_verify_mode => 0x00 });
	$ua->timeout(30); #30s, defaut 180s
	my $response = $ua->request($http_request);
	my $response_json;
	if ($response->is_success ne "1") { #出错,或者timeout了
		$response_json->{status} = "99998";
		$response_json->{is_success} = $response->is_success;
	} else {
		$response_json = parse_response_with_xml_format( $response->content());
		if ($response_json->{return_code} ne "SUCCESS" || $response_json->{result_code} ne "SUCCESS") {
			$response_json->{status} = "99999";
		}
	}
	#syslog("xml:".$response."\njson:".Dumper($response_json)."\nheader:".Dumper($header)."\nreq:".Dumper($http_request)."\nUA:".Dumper($ua));
	syslog("wx-rsp:".Dumper($response_json));
	return {
		response => $response_json,
		request => $PayInfo,		
	};
}

sub alipay_get_prepay_id {
	my $order_info = $_[0];
	
	#my $person_id = $order_info->{person_id};
	my $total_amount = sprintf("%.2f", $order_info->{orderAmount}+0); #订单总金额,单位为元,精确到小数点后两位,取值范围[0.01,100000000]
	
	my $subject = $order_info->{orderId};
	my $out_trade_no = $order_info->{_id};
	my $et_time = $order_info->{createTime};
	
	my $PayInfo;
	$PayInfo->{app_id} = $ALIPAY_CONFIG->{appid};
	my $body = lc(__PACKAGE__);
	my $attach = lc(__PACKAGE__);
	$PayInfo->{biz_content} = '{"body":"'.$body.'","out_trade_no":"'.$order_info->{_id}.'", "product_code":"'.$ALIPAY_CONFIG->{product_code}.'", "subject":"'.$order_info->{orderId}.'","total_amount":"'.$total_amount.'"}';
	
	$PayInfo->{attach} = lc(__PACKAGE__); #添加 工程名字
	$PayInfo->{charset} = $ALIPAY_CONFIG->{charset};
	$PayInfo->{method} = $ALIPAY_CONFIG->{method};
	$PayInfo->{sign_type} = $ALIPAY_CONFIG->{sign_type};
	$PayInfo->{timestamp} = formateTime(time());
	$PayInfo->{notify_url} = $WECHAT_CONFIG->{notify_url};
	$PayInfo->{format} = "json";
	$PayInfo->{version} = "1.0";
	
	my $home = `env`;
	
	$ENV{HOME}="/tmp";
	my $sign = `php /var/www/games/app/yqds/sign.php $attach $body $subject $out_trade_no $total_amount $et_time`;
	
	#my $ret_sign = rsa_sign($PayInfo, $ALIPAY_CONFIG->{rsa_private_key});
	my $ret_sign;
	$ret_sign->{sign} = $sign;
	
	$PayInfo->{sign} = $ret_sign->{sign};
	#对所有value（biz_content作为一个value）进行url encode
	#my $params_sign = {};
	#foreach (keys %{$PayInfo}) {
	#	$params_sign->{$_} = uri_escape_utf8($PayInfo->{$_});
	#}
	#my $sign_string = join( '&',
	#	map { sprintf( '%s=%s', $_, $params_sign->{$_} ) }
	#	sort { $a cmp $b } keys %$params_sign );    
	my $ret;
	#$ret->{sign_str} = $sign_string;
	$ret->{sign_str} = $sign;
	$ret->{unsign} = $ret_sign->{unsign};
	$ret->{sign} = $ret_sign->{sign};
	
	
	$ret->{key} = $ret_sign->{key};
	$ret->{content} = $ret_sign->{content};
	$ret->{home} = $home;
	return $ret;
}

#支付宝支付相关参数
#
# rsa_pkcs8_private：商户pkcs8格式的私钥,生成签名时使用
# ali_rsa_public_key：支付宝公钥, 验证签名时使用
#
$ALIPAY_CONFIG={ 
	appid=>'2018101161628895', #合作者id
	method=>'alipay.trade.app.pay',
	charset=>'utf-8',
	sign_type=>'RSA2',
	product_code=>'QUICK_MSECURITY_PAY',
	#商户私钥(原始格式),有原始格式和pkcs8格式,一般java使用pkcs8格式,php和c#语言使用原始格式。
	ali_rsa_public_key => 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAx8u7aFeCigfYWS334Ccc5lwGmEl8oMQX0rJoyJoZJwwgDE/I2ADaZYjcRs6ZBB0c2fvBHqwtWgPAp/HhfvZkeeBmWds+lHv0rdRRedDFqINtdH1nffuYWlmEZm894td7p1vP4U6mJYkcU3Y5GDza0VGd5xqwHvfKhs0KwozI8ofrhAg6oAG7tv0FyqtV02QR6pZVMNjmWRtYI9U/lgafRLMUWYObYizwLi8APUAsJ1eX834phGOzp73fk/pvW9Q1xRSZG7OTE2/+vH8cfpHEu1ysxzzNyGMy6gpjEQjThE+7YA21TbLjeP93HaPkB3UPXSUos4jROnFBS70pAGCGVwIDAQAB',
	rsa_private_key =>'MIIEpQIBAAKCAQEAx8u7aFeCigfYWS334Ccc5lwGmEl8oMQX0rJoyJoZJwwgDE/I2ADaZYjcRs6ZBB0c2fvBHqwtWgPAp/HhfvZkeeBmWds+lHv0rdRRedDFqINtdH1nffuYWlmEZm894td7p1vP4U6mJYkcU3Y5GDza0VGd5xqwHvfKhs0KwozI8ofrhAg6oAG7tv0FyqtV02QR6pZVMNjmWRtYI9U/lgafRLMUWYObYizwLi8APUAsJ1eX834phGOzp73fk/pvW9Q1xRSZG7OTE2/+vH8cfpHEu1ysxzzNyGMy6gpjEQjThE+7YA21TbLjeP93HaPkB3UPXSUos4jROnFBS70pAGCGVwIDAQABAoIBAQCOCkkx5QTpHKqyu/t9YFErdEE8AwKXSNGm+S+FbghzuisOlaoz5mddx+7SaA5g3lGkp1akd8PGOuS8gTnPCVxlSSN6vmO/LGDHNCq4b7QWGVm3d3AcIMIveXSnXm6g1pESajNf+ookJVX+AA6XLKxkI6IeqtqLKZ7SNvNvXKd/w97WWqGfgpvmeLYrJMvmThO6emRV7encg/ueAU/h7X6rkT3QIA99B9HxjdOZ7uNGeXcVkvTm8JmgMFX+sgVU94MpZixh2mLtUu79kMdYvDPHVvBmvkXcVk88kGg4o/jypKMZ9QWhhGDtWUaI4cckvSmPLCGU/bmv2IGAnOX4DLABAoGBAPchUk5YlT3Zr22coSYH63R9SwN8vlfrLqQb/6DNN/A0WV8VQINuduKxUBNVwvMfFbGZ4lV8auVWnLljL11ifQ795DHLN7dF39ynv8zNuv/yO3N0uXX5spbbdvbAZm7dYphms7GYwcpCNentF0p6YZIblC6Hjsr95scVcghp1Ej7AoGBAM73fmgXZonySeus1jEj8Z1hQrXVaPmf9Vyik5whFeOsZRXJX2dDwkcxy45xrFvnZW4A8CqR9rFjtk1RGdE7d7jiCfRIAc9z8spuETfm+SlWbvvL7Uu0g1v0B0PTYWrbgtHAQIWxXsyiEmjIPWQQkacI1O3boPoHsZdCySg1kPFVAoGASst3+KRQzv5iXN9p2nPNLF17ZZvMlBlm7V5X+NgDlRyS6/cnpl+5dZTKsn9jWGfRDgaP/OWCCNU069r8C9xyEyZ+eR+TRlHMliDjKN4fObWbjq8GLpGbHpNfpwDGP8mbPJrgyeB8znVJkfoi8XSmsSzNpWN7sS41OY3hDHDTQh8CgYEAlfIXYeC6SG0Cgz3IPPf2n/gMNeL02A283S1oVjBeRIHtBpjLhuw/gAcinAPdRQRjpwwE9EKmASTluiRs2PsFpSwW3CWjMiKmH2UZEnBDymA1rjWzqSqSFPe6n7gwlxOMNtzbokC8FvPA9KtGVw3uCJ9MbTu26A7U6mrXhEsyxLUCgYEAze9qLBsjD/KvikBtt76zbekrNWDUUzxnIqilR+g05f5gLXDIFjR8a/WGI85cmv6JlP1QLbYI/We6vGHhGHiYFaHth2Cy/QGwQ8Z4Zc7fB0h/an55zlkeJrYYssg1fV+3AX5M1/4oaBUgD0gSkqOCrPqFUhHQPOEMWv9ZhZy7pvM='
};

#*************************************************************
#微信支付,预支付 prepay id
#↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
#微信支付相关参数

$DNS_NAME = "http://47.104.209.172";
if ((__PACKAGE__) eq "YQDS") {
	#$DNS_NAME = "";
}

$WECHAT_CONFIG={
	user => {#用户端小程序, 公众号
		appid=>'wxcd3f5be2d3b476ab',
    	appSecret=>'cdb3da44af808b8e5125ae57df4fe29e',
    	
    	mch_id => '1516464331',
		appkey => 'Banni18120885256xuexi59187922190',
		trade_type => 'JSAPI'
	},
	user_app => {#用户端APP
		appid=>'wxcd3f5be2d3b476ab',
    	appSecret=>'cdb3da44af808b8e5125ae57df4fe29e',
    	
    	mch_id => '1516464331',
		appkey => 'Banni18120885256xuexi59187922190',
		trade_type => 'APP'
	},
	notify_url => "$DNS_NAME/cgi-bin/yqds.pl", #微信支付回调地址
};

sub RSA_sign{
	my ($key, $content) = @_;
	return 0 unless $content;
	
	my $file_path = "/var/www/games/app/yqds_ga";
	if(uc(__PACKAGE__) eq "YQDS") {
		$file_path = "/var/www/games/app/yqds"
	}
	
	my $sign = "";
	if (!(-e "$file_path/RSA.class")) {#未编译或者是RSA.java有更新
		$sign = `cd $file_path;javac RSA.java;java -cp . RSA '$key' '$content'`;
	} else {
		my $class = (stat "$file_path/RSA.class")[9];#传文件最近一次被修改的unix时间戳
		my $java = (stat "$file_path/RSA.java")[9];
		if ($class < $java) {
			$sign = `cd $file_path;javac RSA.java;java -cp . RSA '$key' '$content'`;
		} else {
			$sign = `cd $file_path;java -cp . RSA '$key' '$content'`;
		}
	}
	chomp($sign); 
	return $sign;
}

sub rsa_sign {
	my ($params, $rsa_private_key)= @_;
	my $params_sign = {};
	foreach ( keys %$params ) {
		next if $_ eq 'sign';
		next unless defined $params->{$_};
		Encode::_utf8_off( $params->{$_} );
		$params_sign->{$_} = $params->{$_};
	}

	my $sign_string = join( '&',
		map { sprintf( '%s=%s', $_, $params_sign->{$_} ) }
		sort { $a cmp $b } keys %$params_sign );

	my $sign = RSA_sign($rsa_private_key, $sign_string);
	#$sign_string .= sprintf( '&sign=%s', $sign );
	my $ret;
	$ret->{sign} = $sign;
	$ret->{unsign} = $sign_string;
	
	
	$ret->{key} = $rsa_private_key;
	$ret->{content} = $sign_string;
	return $ret;
}

# 子程序 - 设置调起微信支付的参数
sub set_wechat_paysign_params {
	my ($prepay_info, $is_app, $now_t) = @_;
	my $temp;
	my $pay_info;
	my $trade_type = "JSAPI";
	if ($is_app eq "false") {# 微信小程序支付返回
		$temp = {
			appId => $prepay_info->{appid},
			timeStamp => "$now_t",
			nonceStr => $prepay_info->{nonce_str},
			package => "prepay_id=".$prepay_info->{prepay_id},
			signType => "MD5"
		};
		$pay_info = { nonceStr=>$temp->{nonceStr}, 
			timeStamp=>$temp->{timeStamp},  signType=> $temp->{signType} };
	} else { # app支付返回 
		$trade_type = "APP";
		$temp = {
			appid => $prepay_info->{appid},
			partnerid => $prepay_info->{mch_id},
			prepayid => $prepay_info->{prepay_id},
			package => "Sign=WXPay",
			noncestr => $prepay_info->{nonce_str},
			timestamp => "$now_t"
		};
		$pay_info = { nonceStr=>$temp->{noncestr},  timeStamp=>$temp->{timestamp},  
			signType=> "MD5", prepayid =>$prepay_info->{prepay_id}, partnerid=>$temp->{partnerid}, appid => $temp->{appid}};
	}
	my $ret = {temp=> $temp, pay_info=> $pay_info, trade_type=> $trade_type};
	return $ret;
}

sub p_homework_deleteAll{
#清空所有作业
	my @homeworkList = mdb()->get_collection("homework")->find()->all();
	foreach my $item(@homeworkList){
		obj_delete("homework", $item->{_id});
	}
	
	my @homeworkInfoList = mdb()->get_collection("booksHomeworkInfo")->find()->all();
	foreach my $item(@homeworkInfoList){
		obj_delete("booksHomeworkInfo", $item->{_id});
	}

	return jr();
}

sub days_calculate{
	my $startTime = $_[0];
	my $endTime = $_[1];
	
	my $days = 0;
	my $second = $endTime - $startTime + 1;
	if($second){
		my $daysTmp = $second / (60*60*24);
		$daysTmp += 0.5;
		$days = int($daysTmp);
	}
	else{
		$days = 0;
	}
	
	return $days;
}

################################################################################
#                                                                              #
#                          DATA STRUCTURE DEFINITIONS                          #
#                                                                              #
################################################################################

# Data structure definitions are required before use.
# Each data structure starts with $man_ds_* prefix, and document will be generated automatically.
# type, _id are reserved key names, and ut/et are normally for update/entry timestamp.
# And use xtype, subtype, cat, category, class etc. for classification label.
# *_fid, *_id are normall added to key name to show the nature of those keys.
# Hash structure is preferred to store list of items before adding/removing/soring
# is easier on hash then on list.

$man_ds_person = <<EOF;
user record, store personal information other than account information

    display_name:123
    
    devicetoken: unique device id
    devicetype: unique device type, android/ios ...
    
	name:
	avatar_fid:
	sex:				性别
	
	school:
	grade:
	class:
	schoolId:			所属学校id
	gradeId
	
	position:			职务(老师/学生)(teacher/student)(新增)
	teacherCode:		学生端教师号
	className:
	teacherCodeList:{	教师端学生好列表
		"":"",			key是教师号,value是班级id
	}
	
	isParent:			学生会有家长控制(是/否)
	parentalPassword:	家长控制的登录密码
	
	permission:			权限(mostAdmin/admin/user)(总管理员/学校管理员/普通用户)
	freeTrial:			免费试用(是/否)
	
    // user personal record update time and entry time
    ut: update time
    et: entry time
EOF

$man_ds_mailbox = <<EOF;
user mailbox, message center, in coming and out going message list

    // id of this record reuses owner's person id
    // cache the last record for each type of conversation.
    // For most of the push, there shall be a record here for user 
    // later viewing purpose just in case user misses the push notification.

    ut: // mailbox update time

    // store the last message, and new message count for each type of message
    messages: {
    
        id1: {  // conversation header id

            htype: chat/topic/group  // conversation header type
            // two party chat (private) or group conversion (not yet implemented)

            hid: same as id1
            ut: unix time, last update time
            vt: unix time, last visit time
            count: new message count under id1
            block: block_record ID for id1
            title: title, subject, group name or private chat party name
			
			// cache the last entry to display on message center message list
            last_user: last user name
            last_content: last message content
            last_avatar: user avatar
        }
    }
EOF

$man_ds_group = <<EOF;
group conversation header structure, more than 2 person
    
    // person ids. 
    members:{
		pid1 => 1,
		pid2 => 1,
	}
    
	title: // group title, subject, name
	avatar_fid: // group logo
	
    // Instead of each person storing header object id, paired person ids of counter party and self 
    // are good enough to locate the chat record.

    // Required field for all conversation header structure.
    block_id: last message entries block record id, for new chat, this fields is set to 0
EOF

$man_ds_chat = <<EOF;
personal two-party conversation header structure
    
    // "chat" in this app is meant for two-party private personal conversation only.
    // Other forms of conversation, group conversation, conversation under certain topics
    // all have similar header structure storing group/topic data, participants, assets, members etc.
    // And each member shall have list of conversation header ids that they are part of.
    
    // Ordered two person ids. Use two ids to look up the header structure
    pair: "id1.id2"
	
	//title: // specially handled in code
	//avatar_fid: // specially handled in code
    
    // Instead of each person storing header object id, paired person ids of counter party and self 
    // are good enough to locate the chat record.

    // Required field for all conversation header structure.
    block_id: last message entries block record id, for new chat, this fields is set to 0
	
EOF

$man_ds_messages_block = <<EOF;
message entries block record, conversation messages are divided into chained blocks

    // next message entries block id. 0 if this is the first block
    // conversation header structure contains the latest block
    next_id: 0

    et: entry time, when this block was first created
    ut: update time, last time when this block was updated
   
    // Conversation entries block contains 50 entries max.
    // All the new entries will be placed on an additional new blocks.

    entries: [
    {
        from_id:     sender id
        from_name:   sender name
        mtype:       text/image/voice/link ...  // message entry type
        content:     content, text, file id, link address etc.
        send_time:   timestamp
    },
    {
        from_id:     sender id
        from_name:   sender name
        mtype:       text/image/voice/link ...
        content:     content, text, file id, link address etc.
        send_time:   timestamp
    }
    ]
EOF

$man_ds_smsmessages = <<EOF;
短信记录表                           
    _id://内建编号
  	phone: //手机号码
    type: smsmessages
  	last_message: {
		content:
		result: // provider return
		xtype: register/modify
		status: //sent
		et: // send time
	},

	messages_log: {
		timestamp1: {
			content:
			result: // provider return
			xtype: register/modify
			status:
			et:  // send time
		}
	}

EOF

$man_ds_geotest = <<EOF;
MongoDB geo location based algorithms test

    "loc": {
        "type": "Point",
        "coordinates": [
            -73.97,
            40.77
        ]
    },
    
    "name": "Central Park",
    "category": "Parks"
EOF

$man_ds_books = <<EOF;
课本
	_id:
    name: "宝葫芦的秘密",		名称
	bookFid:
	guidePrice:100,				导读版售价(单位:元)
	basePrice:100,				基础版售价(单位:元)
	category:					基础版/导读版
    chapterNumber:10,			章节数
	grade:"二年级",				适用的年级
	otherInformation:"",		其他信息
	introduction:				简介
	details:					详情
	chapterID:{					章节id,
		"第一章":"第一章id",
		"第二章":"第二章id"
	},
	recommend:					推荐(是/否)
	status:						上架/下架
	uploadTime:					上架时间
EOF

#$man_ds_chapter = <<EOF;
#章节
#	_id:
#	booksId:					课本id
#    name: "宝葫芦的秘密",		名称
#    chapter:"10章",				章节
#	price:100,					售价(单位:元)
#	piece:[						每个章节的多个部分
#		{
#			page:1~3,
#			firstParagraphOfText:"",		文本第一段(临时演示用)
#			fullText:"",					全文
#			####testQuestions:{
#				multipleChoiceList:[	选择题
#					"o12312132132132"	题目id
#				],
#				fillInTheBlanksList:[
#					"o12312132132132"	题目id
#				]
#			######}
#		},
#	],
#	uploadResources:,			上传资源(上传语音包或者文字包)
#EOF

$man_ds_chapter = <<EOF;
章节
	_id:
	booksId:								课本id
    name: "宝葫芦的秘密",					名称
    chapter:"第10章",						章节
	chapterNum:								第几章
	chapterPage:							章节页码段(36~90)
	piece:[									每个章节的多个部分
		{
			page:1,
			firstParagraphOfText:"",		文本第一段(临时演示用)
			fullText:"",					全文
			timeLimit:120					默读时间限制
		},
	],
	pageSpacing:[							页码间隔
		"1~3",
		"4~7",
		"8~12"
	],
	uploadResources:,						上传资源(上传语音包或者文字包)
	
	guideReadingText:						导读文字
	guideReadingAudio:						导读音频
	
	modelReadingText:						范读文字
	modelReadingAudio:						范读音频
	modelReadingPage:						范读文字所在页码（已弃用）
	modelReadingStartPage					范读文字范围起始页
	modelReadingEndPage						范读文字范围结束页
	
	evaluationQuestion:{					章节评测题
		stem:"",							题干
		option:[							选项
			"A":xxx,
			"B":xxx,
			"C":xxx,
			"D":xxx
		],
		Answer:"A",							选择题答案
		problemAnalysis:					试题解析
	}
EOF

$man_ds_testQuestions = <<EOF;
测试题
	_id:
	chapterID:							所属章节id
	pageSpacing:"1~3",					所属页码间隔
    stem:"",							题干
	option:[							选项
		"A":xxx,
		"B":xxx,
		"C":xxx,
		"D":xxx
	],
	multipleChoiceAnswer:"A",			选择题答案
	fillInTheBlanksAnswer:[				选择题对应填空题答案
		"2",
		"4"
	],
	fillInTheBlanksTimeLimit:120		填空题时限(单位:秒)
	multipleChoiceTimeLimit:120			选择题时限(单位:秒)
EOF

$man_ds_SchoolMember = <<EOF;
学校成员表
	_id:
	city:			市
	cityCode
	area:			区
	areaCode
	school:"",		学校
	schoolCode:		学校编码
	isFreeTrial:	是否免费试用(是/否)
	adminName:
	sex:
	position:
	telephone
	createTime:
	updateTime:
EOF

$man_ds_gradeMember = <<EOF;
年级成员表
	_id:
	city:			市
	area:			区
	school:"",		学校
	grade:			年级
	gradeCode:		年级编码
	schoolId:		所属于学校id
	createTime:
	updateTime:
EOF

$man_ds_classMember = <<EOF;
班级成员表
	_id:
	city:			市
	area:			区
	school:"",		学校
	grade:			年级
	class:			班级
	teacherCode:	班级编码,例如:AA001001
	teacherId:		管理该班级的教师id
	gradeId:		所属年级id
	schoolId:		所属于学校id
	createTime:
	updateTime:
EOF

$man_ds_chapterSchedule = <<EOF;
章节学习进度表
	_id:
	studentId:				学生id
	studentName:
	teacherCode:			教师号
	booksId:					课本id
	bookName:				课本名称
	chapterID:				章节id
	chapterNum
	chapterName:			章节名称
	chapterPage:			章节页码区间
	readingAloudSorce:[
		{
			pageIndex:					页码
			readingAloudFinallyScore:	朗读最后一次成绩
			readingAloudFirstScore:		朗读第一次成绩
			readingAloudHighestScore	最好成绩
			readingAloudCount:			朗读次数
		}
	]
	
	silentReadingScore:{			页码分段(1~3,4~8)
		"1~3":{
			pageSpacing:			页码分段
			Score:		默读成绩
			testQuestions:			默读测试题成绩
			answerTime:				默读答题时间
		}
	}
	
	startTime:				开始时间
	finishTime:				完成时间
	readDays:				阅读天数
	readingState:			阅读状态(未开始/阅读中/已完成)
	
	guideReadingScore:			导读成绩
	modelReadingScore:			范读成绩
	readingAloudTotalSorce:		朗读总成绩---朗读平均成绩
	silentReadingTotalSorce:	默读总成绩---就是默读评测题成绩
	silentReadingAnswerTime:	默读答题时间
	testQuestionsScore:			测试题成绩
	readingAloudProgress:		朗读成绩较上一章的成绩提升
	
	guideReadingState:		导读完成状态
	modelReadingState:		范读完成状态
	readingAloudState:		朗读完成状态
	silentReadingState:		默读完成状态
	testQuestionsState:		测试题完成状态
EOF

$man_ds_readingInfo = <<EOF;
章节阅读信息
	_id:
	studentId:				学生id
	teacherCode:			教师号
	booksId:					课本id
	chapterID:				章节id
	chapterName:			章节名
	bookName:				课本名称
	chapterPage:			章节页码区间
	startTime:				开始时间
	finishTime:				完成时间
	readDays:				阅读天数
	readingState:			阅读状态(未开始/阅读中/已完成)
EOF

$man_ds_homework = <<EOF;
教师发布作业表
	_id:
	teacherId:				教师id
	teacherCode:			教师号
	booksId:				课本id
	bookName:				课本名称
	chapterId:				章节id
	chapterNum:				章节数
	chapterName:			章节名称
	pageSpacing:			页码分段(1~3,4~8)
	category:"导读版",		分类(基础版/导读版)
	startTime:
	finishTime:
	readDays:				阅读天数
	readType:				类型(朗读/默读)
	publishState:			发布状态(未开始/进行中/已完成)
	publistTime:			发布时间
EOF

$man_ds_booksHomeworkInfo = <<EOF;
教师发布作业表的课本信息
	_id:
	teacherId:				教师id
	teacherCode:			教师号
	booksId:				课本id
	bookName:				课本名称
	category:"导读版",		分类(基础版/导读版)
	startTime:
	finishTime:
	readDays:				阅读天数
	publishState:			发布状态(未开始/已完成/进行中)
	publistTime:			发布时间
EOF

$man_ds_homeworkShare = <<EOF;
学生分享的作业表
	_id:
	category:"导读版",		分类(基础版/导读版)
	avatarFid:				学生头像文件id
	studentId:				学生id
	studentName:			学生姓名
	teacherCode:			教师号
	booksId:				课本id
	bookName:				课本名称
	chapterID:				章节id
	chapterName:			章节名称
	pageSpacing:			页码分段(1~3,4~8)
	
	guideReadingScore:		导读成绩
	modelReadingScore:		范读成绩
	readingAloudScore:		朗读成绩
	silentReadingScore:		默读成绩
	testQuestionsScore:		测试题成绩
	
	shareText:				文字
	shareImageList:[]		图片列表
	shareAudioList:[		音频列表
		{
			audioDuration:	音频时长
			audioFid:		音频文件id
		}
	]
	shareVideoList:[			视频列表
		{
			videoThumbnailFid:	视频截图
			videoFid:			视频文件id
		}
	]
	
	uploadTime:				上传作业时间
EOF

$man_ds_praise = <<EOF;
点赞表
	_id
	studentId					作业归属的学生id
	homeworkId:					作业id
	praiseId:					点赞者id
	praiseFid:					点赞者头像fid
	position:					职务(教师/家长)(teacher/parent)
	praiseTime:					点赞时间
EOF

$man_ds_comment = <<EOF;
评论表
	_id
	studentId					作业归属的学生id
	homeworkId:					作业id
	commentId:					评论者id
	commentFid:					评论者头像fid
	position:					职务(教师/家长)(teacher/parent)
	textContent:				评论内容
	commentTime:				评论时间
EOF

$man_ds_favourite = <<EOF;
教师收藏课程表
	_id:
	teacherId:				教师id
	booksId:				课本id
	bookName:				课本名称
	bookFid:				封面图
	grade:"二年级",			适用的年级
	guidePrice
	basePrice
	category
	favouriteTime:			收藏时间
EOF

$man_ds_classGroup = <<EOF;
班级分组表
	_id:
	teacherCode:			教师号
	groupList:{
		groupName:{
			groupName:		组名
			studentList:{
				studentId:{
					studentId:"xxxxxx",	学生id
					studentName:"",		学生姓名
					avatar_fid			头像fid
				}
			}
		}
	},
	otherList:[
		studentList:{
				studentId:{
					studentId:"xxxxxx",	学生id
					studentName:"",		学生姓名
				}
			}
	],
	updateTime:							更新时间
EOF

$man_ds_PaymentBill = <<EOF;
账单
	personId							用于反向查找订单归属的用户
	orderId:							订单id列表
	openid:
	buy_type:								
	orderAmount:						付款金额
	Order_Status						订单状态（待付款/已完成）
	Order_Number						订单号
	createTime							下单时间
EOF

$man_ds_order = <<EOF;
订单
	_id								是id也是订单号
	personId						用于反向查找订单归属的用户

	booksId:						商品ID
	bookName:						商品名称
	bookFid:						商品图片id
	category:						购买资源类型(导读版/基础版)
	price:							商品价格
	Order_Status					订单状态（待付款/已完成）
	createTime						下单时间
	PaymentBillId:					账单号
EOF

$man_ds_classAnnouncement = <<EOF;
班级公告表
	_id
	teacherId					教师id
	teacherCode:				教师号
	textContent:				公告内容
	booksId:
	bookName:
	chapterId:
	chapterName:
	createTime:					添加时间
EOF

$man_ds_studentRoster = <<EOF;
学生名册表
	_id:
	teacherCode:			教师号
	studentName:			学生姓名
	phoneNum:				手机号
	studentNum:				学号
EOF

$man_ds_city = <<EOF;
市表
	_id:
	cityName:		市县名称
	cityCode:		市县编码
EOF

$man_ds_area = <<EOF;
区表
	_id:
	areaName:		区名称
	areaCode:		区编码
	cityName:		
	cityId:			所属市县id
EOF

$man_ds_leaderboard = <<EOF;
章节榜单表
	_id:
	homeworkId:			作业id
	studentList:[		榜单学生列表
		{
			name:
			avatar_fid:
			sex:
		}
	]
EOF

$man_ds_timedTask = <<EOF;
定时随机分组任务
	_id:
	teacherCode:	班级编码,例如:AA001001
	startTime:		开始时间
	timeInterval:	时间间隔
	groupsNumber:	分组数
	status:			状态(开始/结束)
EOF


 
$man_ds_statistics_sale=<<EOF;	
#销售统计数据源
{	 
	_id			 		=> obj_id(),			#统计id
	type 				=> "statistics_sale",				#表名
	person_id			=>,						#用户ID
	time				=>  180809#购买时间	
    book_id             => "",#
	book_name			=> ""#书名
	book_type			=>""#书类型，导读/基础
	book_price			=>#书价格	
	person_city			=> ""#市
	person_area			=> ""#区
	person_school		=> ""#学校
	person_grade		=> ""#年级
	person_class		=> ""#班级
		
	 
}
EOF

$man_ds_statistics_book=<<EOF;	
	_id			 		=> obj_id(),			#统计id
	type 				=> "statistics_book",
	book_id             => "",#
	book_name			=> ""#书名
	
EOF


sub p_statistics_book
{
 
 my ($order_id)=@_;
 my $order=obj_read("order",$order_id);
 my $person=obj_read("person",$order->{personId});
 my $school_id=$person->{schoolId};
 my $school=obj_read("SchoolMember",$school_id);
 my $city=$school->{city};
 my $area=$school->{area};
 my $f={
 
	_id					=>obj_id(),
	type				=>"statistics_book",
	person_id			=>$order->{personId},	
	order_id			=>$order_id,	
	time				=>$order->{createTime},#购买时间	
    book_id             => $order->{booksId},#
	book_name			=> $order->{bookName},#书名
	book_type			=>$order->{category},#书类型，导读/基础
	book_price			=>$order->{price},#书价格	
	person_city			=> $city,#市
	person_area			=> $area,#区
	person_school		=> $person->{school},#学校
	person_grade		=> $person->{grade},#年级
	person_class		=> $person->{class},#班级
 
 };
 obj_write($f);
 	

}

$man_ds_statistics_learning=<<EOF;	
#学习情况统计数据源
{	 
	_id			 		=> obj_id(),			#统计id
	type 				=> "statistics_learning",	 	#表名
	person_id			=>,						#用户ID
	time				=>  180809#统计时间	
    book_id             => "",#
	book_name			=> ""#书名
	person_city			=> ""#市
	person_area			=> ""#区
	person_school		=> ""#学校
	person_grade		=> ""#年级
	person_class		=> ""#班级
	avg_score			=> ""#书的人平均得分（仅限完成）
	finish_rate			=>   #书的完成率=已完成人数/购买人数
	time_cost			=>   #书的平均花费时间（仅限完成）	
	 
}
EOF

 $p_statistics_top10book =<<EOF;
	 输入:
		# time_scale:, #时间尺度（month/day）
	 输出:
		# list:[{date:day/month,
		书名:销量		}] 
EOF

 
sub p_read_person
{
my $person=obj_read("person",$gr->{pid});
return jr({person => $person});
}

sub p_statistics_top10book{

	return jr() unless assert($gr->{time_scale} eq "month" || $gr->{time_scale} eq "day" ,"PLEASE INPUT \"time_scale\"","PLEASE INPUT TIME SCALE","PLEASE INPUT TIME SCALE");
	
	 my @list;
	 my @book_rank;
 if($gr->{time_scale} eq "month" )
 {
 	my $ref;
	$ref={	date=> "一月"};push @list,$ref;
	$ref={	date=> "二月"};push @list,$ref;
	$ref={	date=> "三月"};push @list,$ref;
	$ref={	date=> "四月"};push @list,$ref;
	$ref={	date=> "五月"};push @list,$ref;
	$ref={	date=> "六月"};push @list,$ref;
	$ref={	date=> "七月"};push @list,$ref;
	$ref={	date=> "八月"};push @list,$ref;
	$ref={	date=> "九月"};push @list,$ref;
	$ref={	date=> "十月"};push @list,$ref;
	$ref={	date=> "十一月"};push @list,$ref;
	$ref={	date=> "十二月"};push @list,$ref;
		
  my @statistics=mdb()->get_collection("statistics_book")->find()->all();
	 foreach my $c(@statistics)
	 {
		#检测是否为空
		if(!defined($c->{book_id}))
		{
			next;
		}
		my $bookexist="false";
		for(my $i=0;$i<=$#list;$i=$i+1)
		{
			#遍历@list书名判断是否存在
			if(defined($list[$i]->{$c->{book_name}} ))
			{
				#书存在 
				$bookexist="true";
			}
		
		}
		if($bookexist eq "true")
		{	}
		else
		{
			#不存在就创建
			#用于排序
			$ref=
			{
				book_name=>$c->{book_name},
				amount=>0
			};
			push @book_rank,$ref;
			
			for(my $i=0;$i<=$#list;$i=$i+1)
			{  
				 $list[$i]->{$c->{book_name}} =0;
			} 
		}
		
		my $mon=&ut2mon($c->{time});
		if($mon ne"非2018")
		{ 	
			for($i=0;$i<=$#list;$i=$i+1)
			{
				if(	  $list[$i]->{date} eq $mon )
				{
					$list[$i]->{$c->{book_name}}= $list[$i]->{$c->{book_name}}+  1;
					for($j=0;$j<=$#book_rank;$j=$j+1)
					{
						if( $book_rank[$j]->{book_name} eq  $c->{book_name})
						{
							$book_rank[$j]->{amount}=$book_rank[$j]->{amount}+1;
						} 
					}
					last;				 	
				}				
			} 
		}
		else
		{return jr({error => "order is not in year 2018"});}
	 
	  }
 
	@book_rank=sort{$b->{amount}<=>$a->{amount}} @book_rank;
 }
 elsif($gr->{time_scale} eq "day" )
 {
	my $ref;
	$ref={	date=> "01"};push @list,$ref;
	$ref={	date=> "02"};push @list,$ref;
	$ref={	date=> "03"};push @list,$ref;
	$ref={	date=> "04"};push @list,$ref;
	$ref={	date=> "05"};push @list,$ref;
	$ref={	date=> "06"};push @list,$ref;
	$ref={	date=> "07"};push @list,$ref;
	$ref={	date=> "08"};push @list,$ref;
	$ref={	date=> "09"};push @list,$ref;
	$ref={	date=> "10"};push @list,$ref; 
	$ref={	date=> "11"};push @list,$ref;
	$ref={	date=> "12"};push @list,$ref;
	$ref={	date=> "13"};push @list,$ref;
	$ref={	date=> "14"};push @list,$ref;
	$ref={	date=> "15"};push @list,$ref;
	$ref={	date=> "16"};push @list,$ref;
	$ref={	date=> "17"};push @list,$ref;
	$ref={	date=> "18"};push @list,$ref;
	$ref={	date=> "19"};push @list,$ref;
	$ref={	date=> "20"};push @list,$ref;
	$ref={	date=> "21"};push @list,$ref;
	$ref={	date=> "22"};push @list,$ref;
	$ref={	date=> "23"};push @list,$ref;
	$ref={	date=> "24"};push @list,$ref;
	$ref={	date=> "25"};push @list,$ref;
	$ref={	date=> "26"};push @list,$ref;
	$ref={	date=> "27"};push @list,$ref;
	$ref={	date=> "28"};push @list,$ref;
	$ref={	date=> "29"};push @list,$ref;
	 
	my $mon=&ut2mon(time());
	my @big_months=("一月","三月","五月","七月","八月","十月","十二月");
	
	my @little_months=("四月","六月","九月","十一月");
	if(grep /$mon/,@big_months)#大月31天
	{
		$ref={	date=> "30"};  push @list,$ref;
		$ref={	date=> "31"};push @list,$ref;
		 
	}
	elsif(grep /$mon/,@little_months)#小月30天
	{
		$ref={	date=> "30"};  push @list,$ref; 
	}	 
	
	 
	my @statistics=mdb()->get_collection("statistics_book")->find()->all();
	foreach my $c(@statistics)
	{
		#检测是否为空
		if(!defined($c->{book_id}))
		{
			next;
		} 
		my $bookexist="false";
		for(my $i=0;$i<=$#list;$i=$i+1)
		{#遍历@list书名判断是否存在
			if(defined($list[$i]->{$c->{book_name}}))
			{#书存在 
				$bookexist="true";
			}
		
		}
		if($bookexist eq "true")
		{	}
		else
		{#不存在就创建
			$ref=
			{
				book_name=>$c->{book_name},
				amount=>0
			};
			push @book_rank,$ref;
			
			for(my $i=0;$i<=$#list;$i=$i+1)
			{ 
			 $list[$i]->{$c->{book_name}} =0;  
			} 
		}
		 
		my $day=&ut2day($c->{time});
		if($day ne"非本月")
		{ 
			for($i=0;$i<=$#list;$i=$i+1)
			{
				if(	  $list[$i]->{date} eq $day )
				{
					$list[$i]->{$c->{book_name}}=$list[$i]->{$c->{book_name}}+1;
					for($j=0;$j<=$#book_rank;$j=$j+1)
					{
						if($book_rank[$j]->{book_name} eq  $c->{book_name})
						{
							$book_rank[$j]->{amount}=$book_rank[$j]->{amount}+1;
						} 
					}
					last;				 	
				}				
			} 
		}
		else
		{
			return jr({error => "order is not in month now"});
		}
	 @book_rank=sort{$b->{amount}<=>$a->{amount}} @book_rank;
	 
	 }
	 
	 
 
 }
   
 
	return jr({list => \@list}); 
}
#convert unix time  to  month in 2018
sub ut2mon
{ 
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time());
	$year+=1900;
	my $ut=$_[0];
	my $month=1;
	if($ut >= 1514736000 && $ut < 1517414400)
	{$month="一月";}
	elsif($ut<1519833600){$month="二月";}
	elsif($ut<1522512000){$month="三月";}
	elsif($ut<1525104000){$month="四月";}
	elsif($ut<1527782400){$month="五月";}
	elsif($ut<1530374400){$month="六月";}
	elsif($ut<1533052800){$month="七月";}
	elsif($ut<1535731200){$month="八月";}
	elsif($ut<1538323200){$month="九月";}
	elsif($ut<1541001600){$month="十月";}
	elsif($ut<1543593600){$month="十一月";}
	elsif($ut<1546272000){$month="十二月";}
	else
	{$month="非2018";}
	return $month;
}

#convert unix time to day in 2018
sub ut2day
{
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time());
	$year+=1900;
	$mon+=1;
	my $ut=$_[0];
	my $day=0;
	
	if($ut >= 1514736000 && $ut < 1517414400)
						 {$day=($ut-1514736000)/86400;}
	elsif($ut<1519833600){$day=($ut-1517414400)/86400;}
	elsif($ut<1522512000){$day=($ut-1519833600)/86400;}
	elsif($ut<1525104000){$day=($ut-1522512000)/86400;}
	elsif($ut<1527782400){$day=($ut-1525104000)/86400;}
	elsif($ut<1530374400){$day=($ut-1527782400)/86400;}
	elsif($ut<1533052800){$day=($ut-1530374400)/86400;}
	elsif($ut<1535731200){$day=($ut-1533052800)/86400;}
	elsif($ut<1538323200){$day=($ut-1535731200)/86400;}
	elsif($ut<1541001600){$day=($ut-1538323200)/86400;}
	elsif($ut<1543593600){$day=($ut-1541001600)/86400;}
	elsif($ut<1546272000){$day=($ut-1543593600)/86400;}
	else
	{$day="非本月";}
	if($day ne "非本月")
	{
	$day =int($day+1);
	}
	return $day;
}
  
# ①获取市：cityList_get
# ②获取区：areaList_get
# ③获取学校：
# SchoolMember_get
 
 

$p_statistics_learning =<<EOF;
	# 输入： 
		   # city,	   #市 
		   # area,	   #区
		   # school,	   #学校
	# 输出：	
		# list:[
				book_name:,课程名称
				user_number:,使用人数
				finish_number:,完成人数
				grades:,年级
				avg_point:,平均评分（单位：分）
				total_point:总评分,
				avg_time:,平均完成时间(单位：天)
				total_time:,总时间
				completion_rate:,课程完成率（范围0-1）
				inprocess_number:,课程进行中的人数
				]

EOF

sub p_statistics_learning{


return jr() unless assert (defined($gr->{city}),"至少选择城市","至少选择城市","至少选择城市");
 
if(defined($gr->{school}))
{
	if(!defined($gr->{city}) || !defined($gr->{area}) || $gr->{city} eq "" ||$gr->{area} eq "" )
	{
		return jr({ERR => "未选择市或区"});
	}
	my $school=mdb()->get_collection("SchoolMember")->find_one({city=>$gr->{city},area=>$gr->{area},school=>$gr->{school}});
	if(!defined($school))
	{
		return jr({ERR => "信息有误，无此学校，请检查"});
	}
} 
elsif(defined($gr->{area}))
{
	if(!defined($gr->{city}) || $gr->{city} eq ""  )
	{
		return jr({ERR => "未选择市"});
	}
	my $area=mdb()->get_collection("area")->find_one({cityName=>$gr->{city},areaName=>$gr->{area} });
	if(!defined($area))
	{
		return jr({ERR => "信息有误，无此区，请检查"});
	}
}
else
{
my $city=mdb()->get_collection("city")->find_one({cityName=>$gr->{city}} );
	if(!defined($city))
	{
		return jr({ERR => "信息有误，无此市，请检查"});
	}

}

my @output_list ;
if(defined($gr->{city}))
{
	if(defined($gr->{area}))
	{
		if(defined($gr->{school}))
		{#output school level
		  
			my @orders=mdb()->get_collection("order")->find({Order_Status => "已完成"})->all;
			
			foreach $order(@orders)
			{	
				my $person=mdb()->get_collection("person")->find_one({_id=>$order->{personId}});
				if(defined($person))
				{
				$person=obj_read("person",$order->{personId});
				}
				else
				{next;}
				my $finish_number=0;
				my $inprocess_number=0;
				my $total_point=0;
				my $booksHomeworkInfo=mdb()->get_collection("booksHomeworkInfo")->find_one({teacherCode => $person->{teacherCode},bookName=>$order->{bookName}});
				my $homeworkSharePersonal=mdb()->get_collection("homeworkSharePersonal")->find_one({booksId=>$order->{booksID},personId=>$order->{personId}});
				if($booksHomeworkInfo->{publishState} eq "已完成" )
				{	
					$finish_number=$finish_number+1; 
					$total_point=>$total_point+$homeworkSharePersonal->{total_all};
					
				} 
				elsif($booksHomeworkInfo->{publishState} eq "进行中" )
				{
					$inprocess_number=$inprocess_number+1;
				}
				else
				{
					next;
				}
			
				if($person->{school} eq $gr->{school})
				{
					my $book_exist=0;
					
					
					for($i=0;$i<=$#output_list;$i=$i+1)
					{
					 if(@output_list)
					 {}
					 else
					 {
						last;
					 }
						if($output_list[$i]->{book_name} eq $order->{bookName})
						{
							$book_exist=1;#图书存在
							$output_list[$i]->{user_number}=$output_list[$i]->{user_number}+1;
							if($finish_number == 1)#课程完成
							{
								$output_list[$i]->{finish_number}=	$output_list[$i]->{finish_number}+1;
								$output_list[$i]->{total_point}=	$output_list[$i]->{total_point}+$total_point;
								$output_list[$i]->{total_time}=	$output_list[$i]->{total_time}+$booksHomeworkInfo->{finishTime}-$booksHomeworkInfo->{startTime};
								completion_rate=>0,#课程完成率,
							} 
							elsif($inprocess_number == 1)#课程进行中
							{
							$output_list[$i]->{inprocess_number}=	$output_list[$i]->{inprocess_number}+1;
								
							}
							 
						}
					}
					 
					if($book_exist == 0)
					{
						my $book=obj_read("books",$order->{booksId});
						 
						my $output_list_sub=
						{
							city=>$gr->{city},
							area=>$gr->{area},
							school=>$gr->{school},
							book_name=>$order->{bookName},
							user_number=>1,#使用人数
							finish_number=>0,
							grades=>$book->{grade},#年级
							avg_point=>0,#平均评分
							avg_time=>0,#平均使用时间
							total_point=>0,#总评分,
							total_time=>0,#总时间
							completion_rate=>0,#
							inprocess_number=>0
						 
						};
							if($finish_number == 1)
							{
								$output_list_sub->{finish_number}=	$output_list_sub->{finish_number}+1;
								$output_list_sub->{total_point}=	$output_list_sub->{total_point}+$total_point;
								$output_list_sub->{total_time}=	$output_list_sub->{total_time}+$booksHomeworkInfo->{finishTime}-$booksHomeworkInfo->{startTime};
								
							} 
							elsif($inprocess_number ==1)
							{
								$output_list_sub->{inprocess_number}=	$output_list_sub->{inprocess_number}+1;
						
							}
						push @output_list,$output_list_sub;
		 
					} 
				}
				else
				{
					next;
				}
			}
		
		 
		 
			 
		}
		else
		{#output area level
			 
			my @orders=mdb()->get_collection("order")->find({Order_Status => "已完成"})->all;
			
			foreach $order(@orders)
			{	
				my $person=mdb()->get_collection("person")->find_one({_id=>$order->{personId}});
				if(defined($person))
				{
					$person=obj_read("person",$order->{personId});
				}
				else
				{next;}
				my $finish_number=0;
				my $inprocess_number=0;
				my $total_point=0;
				my $booksHomeworkInfo=mdb()->get_collection("booksHomeworkInfo")->find_one({teacherCode => $person->{teacherCode},bookName=>$order->{bookName}});
				my $homeworkSharePersonal=mdb()->get_collection("homeworkSharePersonal")->find_one({booksId=>$order->{booksID},personId=>$order->{personId}});
				if($booksHomeworkInfo->{publishState} eq "已完成" )
				{	
					$finish_number=$finish_number+1; 
					$total_point=>$total_point+$homeworkSharePersonal->{total_all};
					
				} 
				elsif($booksHomeworkInfo->{publishState} eq "进行中" )
				{
					$inprocess_number=$inprocess_number+1;
				}
				else
				{
					next;
				}
				if(defined($person->{schoolId}))
				{}
				else
				{return jr({ERR=>"此订单的用户的学校id信息有误"});}
				my $school=obj_read("SchoolMember",$person->{schoolId});
				if($school->{area} eq $gr->{area})
				{
					my $book_exist=0;
					
					
					for($i=0;$i<=$#output_list;$i=$i+1)
					{
					 if(@output_list)
					 {}
					 else
					 {
						last;
					 }
						if($output_list[$i]->{book_name} eq $order->{bookName})
						{
							$book_exist=1;#图书存在
							$output_list[$i]->{user_number}=$output_list[$i]->{user_number}+1;
							if($finish_number == 1)#课程完成
							{
								$output_list[$i]->{finish_number}=	$output_list[$i]->{finish_number}+1;
								$output_list[$i]->{total_point}=	$output_list[$i]->{total_point}+$total_point;
								$output_list[$i]->{total_time}=	$output_list[$i]->{total_time}+$booksHomeworkInfo->{finishTime}-$booksHomeworkInfo->{startTime};
								completion_rate=>0,#课程完成率,
							} 
							elsif($inprocess_number == 1)#课程进行中
							{
							$output_list[$i]->{inprocess_number}=	$output_list[$i]->{inprocess_number}+1;
								
							}
							 
						}
					}
					 
					if($book_exist == 0)
					{
						my $book=obj_read("books",$order->{booksId});
						 
						my $output_list_sub=
						{
							city=>$gr->{city},
							area=>$gr->{area},
						 
							book_name=>$order->{bookName},
							user_number=>1,#使用人数
							finish_number=>0,
							grades=>$book->{grade},#年级
							avg_point=>0,#平均评分
							avg_time=>0,#平均使用时间
							total_point=>0,#总评分,
							total_time=>0,#总时间
							completion_rate=>0,#
							inprocess_number=>0
						 
						};
							if($finish_number == 1)
							{
								$output_list_sub->{finish_number}=	$output_list_sub->{finish_number}+1;
								$output_list_sub->{total_point}=	$output_list_sub->{total_point}+$total_point;
								$output_list_sub->{total_time}=	$output_list_sub->{total_time}+$booksHomeworkInfo->{finishTime}-$booksHomeworkInfo->{startTime};
								
							} 
							elsif($inprocess_number ==1)
							{
								$output_list_sub->{inprocess_number}=	$output_list_sub->{inprocess_number}+1;
						
							}
						push @output_list,$output_list_sub;
		 
					} 
				}
				else
				{
					next;
				}
			}
		
		 
		
		
		}
	}
	else
	{#output city level
			 
			my @orders=mdb()->get_collection("order")->find({Order_Status => "已完成"})->all;
			
			foreach $order(@orders)
			{	
				my $person=mdb()->get_collection("person")->find_one({_id=>$order->{personId}});
				if(defined($person))
				{
					$person=obj_read("person",$order->{personId});
				}
				else
				{next;}
				my $finish_number=0;
				my $inprocess_number=0;
				my $total_point=0;
				my $booksHomeworkInfo=mdb()->get_collection("booksHomeworkInfo")->find_one({teacherCode => $person->{teacherCode},bookName=>$order->{bookName}});
				my $homeworkSharePersonal=mdb()->get_collection("homeworkSharePersonal")->find_one({booksId=>$order->{booksID},personId=>$order->{personId}});
				if($booksHomeworkInfo->{publishState} eq "已完成" )
				{	
					$finish_number=$finish_number+1; 
					$total_point=>$total_point+$homeworkSharePersonal->{total_all};
					
				} 
				elsif($booksHomeworkInfo->{publishState} eq "进行中" )
				{
					$inprocess_number=$inprocess_number+1;
				}
				else
				{
					next;
				}
				if(defined($person->{schoolId}))
				{}
				else
				{return jr({ERR=>"此订单的用户的学校id信息有误"});}
				my $school=obj_read("SchoolMember",$person->{schoolId});
				if($school->{city} eq $gr->{city})
				{
					my $book_exist=0;
					
					
					for($i=0;$i<=$#output_list;$i=$i+1)
					{
					 if(@output_list)
					 {}
					 else
					 {
						last;
					 }
						if($output_list[$i]->{book_name} eq $order->{bookName})
						{
							$book_exist=1;#图书存在
							$output_list[$i]->{user_number}=$output_list[$i]->{user_number}+1;
							if($finish_number == 1)#课程完成
							{
								$output_list[$i]->{finish_number}=	$output_list[$i]->{finish_number}+1;
								$output_list[$i]->{total_point}=	$output_list[$i]->{total_point}+$total_point;
								$output_list[$i]->{total_time}=	$output_list[$i]->{total_time}+$booksHomeworkInfo->{finishTime}-$booksHomeworkInfo->{startTime};
								completion_rate=>0,#课程完成率,
							} 
							elsif($inprocess_number == 1)#课程进行中
							{
							$output_list[$i]->{inprocess_number}=	$output_list[$i]->{inprocess_number}+1;
								
							}
							 
						}
					}
					 
					if($book_exist == 0)
					{
						my $book=obj_read("books",$order->{booksId});
						 
						my $output_list_sub=
						{
							city=>$gr->{city},
						 
						 
							book_name=>$order->{bookName},
							user_number=>1,#使用人数
							finish_number=>0,
							grades=>$book->{grade},#年级
							avg_point=>0,#平均评分
							avg_time=>0,#平均使用时间
							total_point=>0,#总评分,
							total_time=>0,#总时间
							completion_rate=>0,#
							inprocess_number=>0
						 
						};
							if($finish_number == 1)
							{
								$output_list_sub->{finish_number}=	$output_list_sub->{finish_number}+1;
								$output_list_sub->{total_point}=	$output_list_sub->{total_point}+$total_point;
								$output_list_sub->{total_time}=	$output_list_sub->{total_time}+$booksHomeworkInfo->{finishTime}-$booksHomeworkInfo->{startTime};
								
							} 
							elsif($inprocess_number ==1)
							{
								$output_list_sub->{inprocess_number}=	$output_list_sub->{inprocess_number}+1;
						
							}
						push @output_list,$output_list_sub;
		 
					} 
				}
				else
				{
					next;
				}
			}
	}
}
else
{
	return jr({ERR => "PLZ CHOOSE A CITY AT LEAST"});
}

foreach $outlist(@output_list)
{
	$outlist->{completion_rate}=sprintf "%.2f",$outlist->{finish_number}/$outlist->{user_number};
	$outlist->{avg_time}=sprintf "%.1f",$outlist->{total_time}/$outlist->{finish_number}/86400;
	$outlist->{avg_point}=sprintf "%.2f",$outlist->{total_point}/$outlist->{finish_number};

	}
	
	return jr({list => \@output_list});
}

 

$p_statistics_order_amount=<<EOF;
	输入；
		time_scale:, #时间尺度，输入month或day
	输出：	
		list:[日/月,订单量] 
EOF



sub p_statistics_order_amount{

	return jr() unless assert($gr->{time_scale} eq "month" || $gr->{time_scale} eq "day" ,"PLEASE INPUT \"time_scale\"","PLEASE INPUT TIME SCALE","PLEASE INPUT TIME SCALE");
	
	my @list;
	if($gr->{time_scale} eq "month" )
	{
		my $ref;
		$ref={total_amount=>0};push @list,$ref;
		$ref={time=>"一月",amount=>0};push @list,$ref;
		$ref={time=>"二月",amount=>0};push @list,$ref;
		$ref={time=>"三月",amount=>0};push @list,$ref;
		$ref={time=>"四月",amount=>0};push @list,$ref;
		$ref={time=>"五月",amount=>0};push @list,$ref;
		$ref={time=>"六月",amount=>0};push @list,$ref;
		$ref={time=>"七月",amount=>0};push @list,$ref;
		$ref={time=>"八月",amount=>0};push @list,$ref;
		$ref={time=>"九月",amount=>0};push @list,$ref;
		$ref={time=>"十月",amount=>0};push @list,$ref;
		$ref={time=>"十一月",amount=>0};push @list,$ref;
		$ref={time=>"十二月",amount=>0};push @list,$ref;
 
 
				
		my @orderS=mdb()->get_collection("order")->find()->all();
		foreach my $order(@orderS)
		{ 
			
			my $mon=&ut2mon($order->{createTime});
			if($mon ne"非2018")
			{ 	
				for(my $i=0;$i<=$#list;$i=$i+1)
				{	  
					if($list[$i]->{time} eq $mon)
					{ 
						$list[$i]->{amount}=$list[$i]->{amount}+1;
						$list[0]->{total}= $list[0]->{total}+1;   
					}
				}
			}
			else
			{
				return jr({error => "order is not in year 2018"});
			} 
		} 
	}
  
	elsif($gr->{time_scale} eq "day" )
	{  

		my $ref;
		$ref={total_amount=>0};push @list,$ref;
		$ref={time=>"01",amount=>0};push @list,$ref;
		$ref={time=>"02",amount=>0};push @list,$ref;
		$ref={time=>"03",amount=>0};push @list,$ref;
		$ref={time=>"04",amount=>0};push @list,$ref;
		$ref={time=>"05",amount=>0};push @list,$ref;
		$ref={time=>"06",amount=>0};push @list,$ref;
		$ref={time=>"07",amount=>0};push @list,$ref;
		$ref={time=>"08",amount=>0};push @list,$ref;
		$ref={time=>"09",amount=>0};push @list,$ref;
		$ref={time=>"10",amount=>0};push @list,$ref;
		$ref={time=>"11",amount=>0};push @list,$ref;
		$ref={time=>"12",amount=>0};push @list,$ref;
		$ref={time=>"13",amount=>0};push @list,$ref;
		$ref={time=>"14",amount=>0};push @list,$ref;
		$ref={time=>"15",amount=>0};push @list,$ref;
		$ref={time=>"16",amount=>0};push @list,$ref;
		$ref={time=>"17",amount=>0};push @list,$ref;
		$ref={time=>"18",amount=>0};push @list,$ref;
		$ref={time=>"19",amount=>0};push @list,$ref;
		$ref={time=>"20",amount=>0};push @list,$ref;
		$ref={time=>"21",amount=>0};push @list,$ref;
		$ref={time=>"22",amount=>0};push @list,$ref;
		$ref={time=>"23",amount=>0};push @list,$ref;
		$ref={time=>"24",amount=>0};push @list,$ref;
		$ref={time=>"25",amount=>0};push @list,$ref;
		$ref={time=>"26",amount=>0};push @list,$ref;
		$ref={time=>"27",amount=>0};push @list,$ref;
		$ref={time=>"28",amount=>0};push @list,$ref;
		$ref={time=>"29",amount=>0};push @list,$ref; 
		
		my $mon=&ut2mon(time());
		my @big_months=("一月","三月","五月","七月","八月","十月","十二月");
		
		my @little_months=("四月","六月","九月","十一月");
		if(grep /$mon/,@big_months)#大月31天
		{
		
		$ref={time=>"30",amount=>0};push @list,$ref;
		$ref={time=>"31",amount=>0};push @list,$ref;
	 
		}
		elsif(grep /$mon/,@little_months)#小月30天
		{
			 
		$ref={time=>"30",amount=>0};push @list,$ref;
		}	
		push @list,$ref;
		
		
		
		my @orderS=mdb()->get_collection("order")->find()->all();
		foreach my $order(@orderS)
		{
		
		my $theMon=&ut2mon(time());
		my $mon=&ut2mon($order->{createTime});
		my $day=&ut2day($order->{createTime});
		if($day ne"非本月")
		{ 
			 
			for(my $i=0;$i<=$#list;$i=$i+1)
			{	  
				if($list[$i]->{time} eq $day)
				{ 
					$list[$i]->{amount}=$list[$i]->{amount}+1;
					$list[0]->{total}= $list[0]->{total}+1;  
				}
			} 
		}
		else
		{
			return jr({error => "order is not in month now"});}
			 		
		}
		
	 
	 }
	return jr({list => \@list}); 
}

$p_statistics_order_totalpay=<<EOF;
	输入；
		time_scale:, #时间尺度（month/day）
	输出：	
		list:[month/day,销售额] 

EOF



sub p_statistics_order_totalpay{

	
	return jr() unless assert($gr->{time_scale} eq "month" || $gr->{time_scale} eq "day" ,"PLEASE INPUT \"time_scale\"","PLEASE INPUT TIME SCALE","PLEASE INPUT TIME SCALE");
	
	my @list;
	if($gr->{time_scale} eq "month" )
	{
			 
		$ref={total_amount=>0};push @list,$ref;
		$ref={time=>"一月",amount=>0};push @list,$ref;
		$ref={time=>"二月",amount=>0};push @list,$ref;
		$ref={time=>"三月",amount=>0};push @list,$ref;
		$ref={time=>"四月",amount=>0};push @list,$ref;
		$ref={time=>"五月",amount=>0};push @list,$ref;
		$ref={time=>"六月",amount=>0};push @list,$ref;
		$ref={time=>"七月",amount=>0};push @list,$ref;
		$ref={time=>"八月",amount=>0};push @list,$ref;
		$ref={time=>"九月",amount=>0};push @list,$ref;
		$ref={time=>"十月",amount=>0};push @list,$ref;
		$ref={time=>"十一月",amount=>0};push @list,$ref;
		$ref={time=>"十二月",amount=>0};push @list,$ref;
 
				
		my @orderS=mdb()->get_collection("order")->find()->all();
		foreach my $order(@orderS)
		{ 
			
			my $mon=&ut2mon($order->{createTime});
			if($mon ne"非2018")
			{ 	
				for(my $i=0;$i<=$#list;$i=$i+1)
				{	  
					if($list[$i]->{time} eq $mon)
					{ 
						$list[$i]->{amount}=$list[$i]->{amount}+$order->{price};
						$list[0]->{total}= $list[0]->{total}+$order->{price};   
					}
				} 
			}
			else
			{return jr({error => "order is not in year 2018"});}
		 
		}
	 
		 
	}
  
	elsif($gr->{time_scale} eq "day" )
	{  
		$ref={total_amount=>0};push @list,$ref;
		$ref={time=>"01",amount=>0};push @list,$ref;
		$ref={time=>"02",amount=>0};push @list,$ref;
		$ref={time=>"03",amount=>0};push @list,$ref;
		$ref={time=>"04",amount=>0};push @list,$ref;
		$ref={time=>"05",amount=>0};push @list,$ref;
		$ref={time=>"06",amount=>0};push @list,$ref;
		$ref={time=>"07",amount=>0};push @list,$ref;
		$ref={time=>"08",amount=>0};push @list,$ref;
		$ref={time=>"09",amount=>0};push @list,$ref;
		$ref={time=>"10",amount=>0};push @list,$ref;
		$ref={time=>"11",amount=>0};push @list,$ref;
		$ref={time=>"12",amount=>0};push @list,$ref;
		$ref={time=>"13",amount=>0};push @list,$ref;
		$ref={time=>"14",amount=>0};push @list,$ref;
		$ref={time=>"15",amount=>0};push @list,$ref;
		$ref={time=>"16",amount=>0};push @list,$ref;
		$ref={time=>"17",amount=>0};push @list,$ref;
		$ref={time=>"18",amount=>0};push @list,$ref;
		$ref={time=>"19",amount=>0};push @list,$ref;
		$ref={time=>"20",amount=>0};push @list,$ref;
		$ref={time=>"21",amount=>0};push @list,$ref;
		$ref={time=>"22",amount=>0};push @list,$ref;
		$ref={time=>"23",amount=>0};push @list,$ref;
		$ref={time=>"24",amount=>0};push @list,$ref;
		$ref={time=>"25",amount=>0};push @list,$ref;
		$ref={time=>"26",amount=>0};push @list,$ref;
		$ref={time=>"27",amount=>0};push @list,$ref;
		$ref={time=>"28",amount=>0};push @list,$ref;
		$ref={time=>"29",amount=>0};push @list,$ref; 
		
		my $mon=&ut2mon(time());
		my @big_months=("一月","三月","五月","七月","八月","十月","十二月");
		
		my @little_months=("四月","六月","九月","十一月");
		if(grep /$mon/,@big_months)#大月31天
		{
			$ref={time=>"30",amount=>0};push @list,$ref;
			$ref={time=>"31",amount=>0};push @list,$ref;
			 
		}
		elsif(grep /$mon/,@little_months)#小月30天
		{
			 
			$ref={time=>"30",amount=>0};push @list,$ref;
		}	
		push @list,$ref;
			
		
		
		my @orderS=mdb()->get_collection("order")->find()->all();
		foreach my $order(@orderS)
		{
		
		my $theMon=&ut2mon(time());
		my $mon=&ut2mon($order->{createTime});
		my $day=&ut2day($order->{createTime});
		if($day ne"非本月")
		{ 
			for(my $i=0;$i<=$#list;$i=$i+1)
			{	  
				if($list[$i]->{time} eq $day)
				{ 
					$list[$i]->{amount}=$list[$i]->{amount}+$order->{price};
					$list[0]->{total}= $list[0]->{total}+$order->{price};   
				}
			} 			 
		}
		else
		{
			return jr({error => "order is not in month now"});}
			 		
		}
		
	 
	 }
	return jr({list => \@list}); 
}
# 2.用户数量
$p_statistics_customer=<<EOF;
	输入： time_scale, #时间尺度（day/month）
		 
    输出：list[{
				市=>"",
				区=>"",
				day/month=>333 #学生数量
				}]   
EOF



sub p_statistics_customer{
	return jr() unless assert($gr->{time_scale} eq "month" || $gr->{time_scale} eq "day" ,"PLEASE INPUT \"time_scale\"","PLEASE INPUT TIME SCALE","PLEASE INPUT TIME SCALE");
	
	my @list;
	if($gr->{time_scale} eq "month" )
	{
		 my $ref;
		$ref={	date=> "一月"};push @list,$ref;
		$ref={	date=> "二月"};push @list,$ref;
		$ref={	date=> "三月"};push @list,$ref;
		$ref={	date=> "四月"};push @list,$ref;
		$ref={	date=> "五月"};push @list,$ref;
		$ref={	date=> "六月"};push @list,$ref;
		$ref={	date=> "七月"};push @list,$ref;
		$ref={	date=> "八月"};push @list,$ref;
		$ref={	date=> "九月"};push @list,$ref;
		$ref={	date=> "十月"};push @list,$ref;
		$ref={	date=> "十一月"};push @list,$ref;
		$ref={	date=> "十二月"};push @list,$ref;
		
		my @statistics=mdb()->get_collection("person")->find()->all();
		foreach my $person(@statistics)
		{
			my $school=obj_read("SchoolMember",$person->{schoolId});			
			my $city_area_exist="false";
			for(my $i=0;$i<=$#list;$i=$i+1)
			{
				#遍历@list ，判断数量统计是否存在
				if(defined($list[$i]->{$school->{city}.$school->{area}}))
				{
					#数量统计存在 
					$city_area_exist="true";
				} 
			}
		
		if(city_area_exist eq "true")
		{	}
		else
		{
			 
			for(my $i=0;$i<= $#list;$i=$i+1)
			{
				$list[$i]->{$school->{city}.$school->{area}}=0;
			}
		}
		
		my @personS=mdb()->get_collection("person")->find()->all();
		foreach my $person(@personS)
		{ 
			my $school=obj_read("SchoolMember",$person->{schoolId});
			
			my $mon=&ut2mon($person->{ut});
			if($mon ne"非2018")
			{ 	
				for($i=0;$i<=$#list;$i=$i+1)
				{
					if(	 $list[$i]->{date} eq $mon )
					{
						$list[$i]->{$school->{city}.$school->{area}}=$list[$i]->{$school->{city}.$school->{area}}+1;						 
						last;				 	
					}				
				} 
			}
			else
			{
				return jr({error => "order is not in year 2018"});
			} 
		}
	  
	}
  }
 elsif($gr->{time_scale} eq "day" )
 {
	my $ref;
	$ref={	date=> "01"};push @list,$ref;
	$ref={	date=> "02"};push @list,$ref;
	$ref={	date=> "03"};push @list,$ref;
	$ref={	date=> "04"};push @list,$ref;
	$ref={	date=> "05"};push @list,$ref;
	$ref={	date=> "06"};push @list,$ref;
	$ref={	date=> "07"};push @list,$ref;
	$ref={	date=> "08"};push @list,$ref;
	$ref={	date=> "09"};push @list,$ref;
	$ref={	date=> "10"};push @list,$ref; 
	$ref={	date=> "11"};push @list,$ref;
	$ref={	date=> "12"};push @list,$ref;
	$ref={	date=> "13"};push @list,$ref;
	$ref={	date=> "14"};push @list,$ref;
	$ref={	date=> "15"};push @list,$ref;
	$ref={	date=> "16"};push @list,$ref;
	$ref={	date=> "17"};push @list,$ref;
	$ref={	date=> "18"};push @list,$ref;
	$ref={	date=> "19"};push @list,$ref;
	$ref={	date=> "20"};push @list,$ref;
	$ref={	date=> "21"};push @list,$ref;
	$ref={	date=> "22"};push @list,$ref;
	$ref={	date=> "23"};push @list,$ref;
	$ref={	date=> "24"};push @list,$ref;
	$ref={	date=> "25"};push @list,$ref;
	$ref={	date=> "26"};push @list,$ref;
	$ref={	date=> "27"};push @list,$ref;
	$ref={	date=> "28"};push @list,$ref;
	$ref={	date=> "29"};push @list,$ref;
	 
	my $mon=&ut2mon(time());
	my @big_months=("一月","三月","五月","七月","八月","十月","十二月");
	
	my @little_months=("四月","六月","九月","十一月");
	if(grep /$mon/,@big_months)#大月31天
	{
		$ref={	date=> "30"};  push @list,$ref;
		$ref={	date=> "31"};push @list,$ref;
		 
	}
	elsif(grep /$mon/,@little_months)#小月30天
	{
		$ref={	date=> "30"};  push @list,$ref; 
	}	 
	
 
	my @statistics=mdb()->get_collection("person")->find()->all();
	foreach my $person(@statistics)
	{
		my $school=obj_read("SchoolMember",$person->{schoolId});		
		if(!$school)
		{next;}
		my $city_area_exist="false";
		for(my $i=0;$i<=$#list;$i=$i+1)
		{
			#遍历@list书名判断是否存在
			if(defined($list[$i]->{$school->{city}.$school->{area}}))
			{
				#书存在 
				$city_area_exist="true";
			} 
		}
		
		if($city_area_exist eq "true")
		{	}
		else
		{
			#不存在就创建
			for(my $i=0;$i<=$#list;$i=$i+1)
			{ 
				$list[$i]->{$school->{city}.$school->{area}} = 0; 
			}  
		} 
		
		my $day=&ut2day($person->{ut});
		 
		if($day ne"非本月")
		{ 
			for($i=0;$i<=$#list;$i=$i+1)
			{
				if($list[$i]->{date} eq $day)
				{ 
					$list[$i]->{$school->{city}.$school->{area}}= $list[$i]->{$school->{city}.$school->{area}}+1;
					last;				 	
				}				
			} 
		}
		else
		{
			return jr({error => "order is not in month now"});
		} 
	 } 
 }
   
 
	return jr({list => \@list}); 
}

$p_statistics_school=<<EOF;

	输入： time_scale, #时间尺度（day/month）
		  
		    
	输出：list[{
				市=>"",
				区=>"",
			 
				day/month=>333 #日期=>学校数量
				}]  
EOF

 
#学校数量统计
sub p_statistics_school{
	#输入判断
	return jr() unless assert($gr->{time_scale} eq "month" || $gr->{time_scale} eq "day" ,"PLEASE INPUT \"time_scale\"","PLEASE INPUT TIME SCALE","PLEASE INPUT TIME SCALE");
	
	#声明
	my @list;
	my @datelist;
	
	#按月份输出
	if($gr->{time_scale} eq "month" )
	{
		#构建初始列表
		my $ref;
		$ref={	date=> "一月"};push @list,$ref;
		$ref={	date=> "二月"};push @list,$ref;
		$ref={	date=> "三月"};push @list,$ref;
		$ref={	date=> "四月"};push @list,$ref;
		$ref={	date=> "五月"};push @list,$ref;
		$ref={	date=> "六月"};push @list,$ref;
		$ref={	date=> "七月"};push @list,$ref;
		$ref={	date=> "八月"};push @list,$ref;
		$ref={	date=> "九月"};push @list,$ref;
		$ref={	date=> "十月"};push @list,$ref;
		$ref={	date=> "十一月"};push @list,$ref;
		$ref={	date=> "十二月"};push @list,$ref;
		 
	my @statistics=mdb()->get_collection("SchoolMember")->find()->all();
	 foreach my $school(@statistics)
	 {
	 		
		my $school_exist="false";
		for(my $i=0;$i<=$#list;$i=$i+1)
		{#遍历@list ，判断数量统计是否存在
			if( defined($list[$i]->{$school->{city}.$school->{area}}))
			{#数量统计存在 
				$school_exist="true";
			}
		
		}
		
		if(school_exist eq "true")
		{	}
		else
		{
			for(my $i=0;$i<= $#list;$i=$i+1)
			{
				$list[$i]->{$school->{city}.$school->{area}}=0;
			}
		}
		
		my @schoolS=mdb()->get_collection("SchoolMember")->find()->all();
		foreach my $school(@schoolS)
		{ 
			 
			
			my $mon=&ut2mon($school->{createTime});
			if($mon ne"非2018")
			{ 	
				for($i=0;$i<=$#list;$i=$i+1)
				{
					if(	 $list[$i]->{date} eq $mon  )
					{
						$list[$i]->{$school->{city}.$school->{area}}=$list[$i]->{$school->{city}.$school->{area}}+1;
				
						last;				 	
					}				
				} 
			}
			else
			{return jr({error => "order is not in year 2018"});}
		 
		}
	 
		
	}
  }
 elsif($gr->{time_scale} eq "day" ){
 
	my $ref;
	$ref={	date=> "01"};push @list,$ref;
	$ref={	date=> "02"};push @list,$ref;
	$ref={	date=> "03"};push @list,$ref;
	$ref={	date=> "04"};push @list,$ref;
	$ref={	date=> "05"};push @list,$ref;
	$ref={	date=> "06"};push @list,$ref;
	$ref={	date=> "07"};push @list,$ref;
	$ref={	date=> "08"};push @list,$ref;
	$ref={	date=> "09"};push @list,$ref;
	$ref={	date=> "10"};push @list,$ref; 
	$ref={	date=> "11"};push @list,$ref;
	$ref={	date=> "12"};push @list,$ref;
	$ref={	date=> "13"};push @list,$ref;
	$ref={	date=> "14"};push @list,$ref;
	$ref={	date=> "15"};push @list,$ref;
	$ref={	date=> "16"};push @list,$ref;
	$ref={	date=> "17"};push @list,$ref;
	$ref={	date=> "18"};push @list,$ref;
	$ref={	date=> "19"};push @list,$ref;
	$ref={	date=> "20"};push @list,$ref;
	$ref={	date=> "21"};push @list,$ref;
	$ref={	date=> "22"};push @list,$ref;
	$ref={	date=> "23"};push @list,$ref;
	$ref={	date=> "24"};push @list,$ref;
	$ref={	date=> "25"};push @list,$ref;
	$ref={	date=> "26"};push @list,$ref;
	$ref={	date=> "27"};push @list,$ref;
	$ref={	date=> "28"};push @list,$ref;
	$ref={	date=> "29"};push @list,$ref;
		 	my $mon=&ut2mon(time());
			my @big_months=("一月","三月","五月","七月","八月","十月","十二月");
			
			my @little_months=("四月","六月","九月","十一月");
			if(grep /$mon/,@big_months)#大月31天
			{
				$ref={	date=> "30"};  push @list,$ref;
				$ref={	date=> "31"};push @list,$ref;
				 
			}
			elsif(grep /$mon/,@little_months)#小月30天
			{
				 
					$ref={	date=> "30"};  push @list,$ref; 
			}	 
		 
 
  my @statistics=mdb()->get_collection("SchoolMember")->find()->all();
	 foreach my $school(@statistics)
	 { 
		my $school_exist="false";
		for(my $i=0;$i<=$#list;$i=$i+1)
		{#遍历@list书名判断是否存在
			if(defined($list[$i]->{$school->{city}.$school->{area}}) )
			{#书存在 
				 
				$school_exist="true";
			}
		
		}
		if($school_exist eq "true")
		{	 }
		else
		{#不存在就创建
			 
			for(my $i=0;$i<=$#list;$i=$i+1)
			{#遍历@list书名判断是否存在
			 $list[$i]->{$school->{city}.$school->{area}} = 0;
	 
			} 
			  
		}
		
	
		
		
		my $day=&ut2day($school->{createTime});
		 
		if($day ne"非本月")
		{ push @datelist,$day;
			for($i=0;$i<=$#list;$i=$i+1)
			{
				if(	  $list[$i]->{date} eq $day)
				{
				 
					 $list[$i]->{$school->{city}.$school->{area}}=$list[$i]->{$school->{city}.$school->{area}}+1;
				 
		 
					last;				 	
				}				
			} 
		}
		else
		{return jr({error => "order is not in month now"});}
	  
	 
	 }
	 
	 
 
 }
   
 
	return jr({list => \@list }); 
} 
 
#APPID: 2018052960313213

#微信支付
#AppID：wxcd3f5be2d3b476ab
#cdb3da44af808b8e5125ae57df4fe29e
#appid=>'wxcd3f5be2d3b476ab',
#appSecret=>'cdb3da44af808b8e5125ae57df4fe29e'
#mch_id => '1516464331',
#appkey => 'Banni18120885256xuexi59187922190',

=pod
=for tanshuil/begin
=cut

$p_system_paytype_set = <<EOF;
设定支付方式的显隐
输入：
{
	wechat: 1,
	alipay: 1,
	apple:1
}
输出：
{
	state: success, // 至少改变一个值返回成功，否则 fail
	wechat: new_value,
	alipay: new_value,
	apple:new_value
}
示例：{"obj":"system","act":"paytype_set","wechat":0,"alipay":0,"apple":1}
EOF

sub p_system_paytype_set
{
	if (not (defined $gr->{wechat} || defined $gr->{alipay} || defined $gr{apple})) {
		return jr({state => "fail"});
	}

	my $old = obj_read('system', 'paytype');
	my $wechat = $old->{wechat} || 0;
	my $alipay = $old->{alipay} || 0;
	my $apple = $old->{apple} || 0;
	if (defined $gr->{wechat}) {
		$wechat = 0 + $gr->{wechat};
	}
	if (defined $gr->{alipay}) {
		$alipay = 0 + $gr->{alipay};
	}
	if (defined $gr->{apple}) {
		$apple = 0 + $gr->{apple};
	}

	my $ref = {
		_id => "paytype",
		type => "system",
		wechat => $wechat,
		alipay => $alipay,
		apple => $apple,
	};
	obj_write($ref);

	return jr({state => "success",
			wechat => $wechat,
			alipay => $alipay,
			apple => $apple,
		});
}

$p_system_paytype_qry = <<EOF;
查询支付方式的显隐
输入：无
输出：每种支付方式的显隐 1/0
{
	wechat: 1/0,
	alipay: 1/0,
	apple: 1/0
}
示例：{"obj":"system","act":"paytype_qry"}
EOF

sub p_system_paytype_qry
{
	my $old = obj_read('system', 'paytype');
	return jr({state => 'fail'}) unless $old;

	my $wechat = $old->{wechat} || 0;
	my $alipay = $old->{alipay} || 0;
	my $apple = $old->{apple} || 0;

	return jr({state => "success",
			wechat => $wechat,
			alipay => $alipay,
			apple => $apple,
		});
}

=pod
=for tanshuil/end
=cut
