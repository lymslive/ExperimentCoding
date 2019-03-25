#ifndef JSON_EXTEND_CONFIG_H__
#define JSON_EXTEND_CONFIG_H__

#include "commonutil/api_logger.h"

namespace Json {
namespace Sql {

// typedef JSONCPP_STRING String;
#define String JSONCPP_STRING
#define EINT int

// #define ASSERT_RET(expr, args...) do{if (!(expr)){LOG_ERR("assert \"%s\" failed", #expr); return	args; }}while(0)
// #define ASSERT_RET(expr, args...) do{if (!(expr)){return args; }}while(0)

// 日志相关宏
#define LOG_ERR log_error
#define LOG_DBG log_debug

#define LOG_STR(s) LOG_DBG((s).c_str())

#ifdef NDEBUG
#define ASSERT_RET(expr, args...) do{if (!(expr)){return args; }}while(0)
#else
#define ASSERT_RET(expr, args...) do{if (!(expr)){LOG_ERR("assert \"%s\" failed", #expr); return args; }}while(0)
#endif

} // namespace Sql
} // namespace Json


#endif /* end of include guard: CONFIG_H__ */
