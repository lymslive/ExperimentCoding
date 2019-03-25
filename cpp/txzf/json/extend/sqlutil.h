#ifndef JSON_EXTEND_SQLUTIL_H__
#define JSON_EXTEND_SQLUTIL_H__

#include "./config.h"
#include "../value.h"

namespace Json {
namespace Sql {

// 构造 sql 语句字符串
// table 是表名
// columns 是 json 对象，包含多字段
// keys 是只包含主键的 json 的对象，用于构造 where 子句，
// 非 json 对象时，用 "where 1=1 " 代替
String Insert(const String& table, const Json::Value& columns);
String Replace(const String& table, const Json::Value& columns);
String Update(const String& table, const Json::Value& columns, const Json::Value& keys);
String Select(const String& table, const Json::Value& columns, const Json::Value& keys);

// 连接构造条件子串，适于追加在 "WHTER 1=1 " 之后
// compare 可取值如：= != < > LIKE 等，默认 = ，会在前后附加一个空格
// columns 允许含多个字段值，都用相同的比较，并用 AND 连接
String Where(const Json::Value& columns, const char* compare = NULL);

} // namespace Sql
} // namespace Json

#endif /* end of include guard: SQLUTIL_H__ */
