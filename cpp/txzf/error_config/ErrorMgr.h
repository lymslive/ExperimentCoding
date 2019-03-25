#ifndef TFBTRADE_ERRORMGR_H__
#define TFBTRADE_ERRORMGR_H__

#include <string>
#include <map>

#include "commonutil/api_mysql.h"

namespace TFBError
{

// 错误码配置表
#define ERROR_TABLE "trade.t_error_config"
// 通用错误类名
#define ERROR_COMM "'common'"

// 一些常量宏
typedef int EINT;
typedef const char* EMSG;
const EINT OK = 0;
const EINT NOK = -1;
inline bool SUCCESS(EINT error) { return error == OK; }

// 便捷使用的纯结构体
struct error_t
{
	EINT error;
	std::string errstr;

	error_t() : error(NOK), errstr("异常错误") {}
	error_t(EINT e, EMSG s) : error(e), errstr(s) {}
	error_t(EINT e, std::string str) : error(e), errstr(str) {}
};

class CErrorMgr
{
public:
	// 获取错误相应的错误消息，可提供缺省默认值
	EMSG GetErrstr(EINT error, EMSG pDefault = NULL);

	// 初始化加载错误表
	// 要提供 mysql 连接对象
	// 可提供额外的错误类别，附在通用类 "common" 之后，多个类别用 "," 分隔
	// EINT LoadError(const char* group = NULL) { return NOK; }
	EINT LoadError(MysqlConnScopedPtr& conn, const char* group = NULL);

	static CErrorMgr& Instance();
private:
	std::map<int, std::string> m_mapErrstr;
};

// 对外函数接口
EINT Init(MysqlConnScopedPtr& conn, const char* group = NULL);
EMSG GetErrstr(EINT error, EMSG pDefault = NULL);
}
#endif /* end of include guard: ERRORMGR_H__ */
