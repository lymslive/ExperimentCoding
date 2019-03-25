#ifndef JSON_EXTEND_SQLOPER_H__
#define JSON_EXTEND_SQLOPER_H__

#include "./config.h"
#include "../value.h"
#include "sqlutil.h"
#include "commonutil/api_mysql.h"

namespace Json {
namespace Sql {

// 执行 sql 语句，返回错误码
// 构建 sql 语句参考 sqlutil.h 相应的函数

// 插入一行记录，检查影响行数是否为 1
EINT doInsert(MysqlConnScopedPtr& conn, const String& table, const Json::Value& columns, int affect = 1);
// 替换插入一行记录，检查影响行数不小于1，替换发生影响两行
EINT doReplace(MysqlConnScopedPtr& conn, const String& table, const Json::Value& columns);

// 更新记录
// affect 是期待影响的行数，不匹配时返回非0错误码；
// 默认 1 行，0 或负数表示不确定影响行数，不检查
EINT doUpdate(MysqlConnScopedPtr& conn, const String& table, const Json::Value& columns, const Json::Value& keys, int affect = 1);
EINT doSelect(MysqlConnScopedPtr& conn, const String& table, Json::Value& columns, const Json::Value& keys);

// 重载，直接提供 where 子串（假定附加在 WHERE 1=1 或其他条件之后的 AND ... 条件）
// 其他额外的 sql 语素如 order by limit 等也可以组装在 where 参数中
EINT doUpdate(MysqlConnScopedPtr& conn, const String& table, const Json::Value& columns, const String& where, int affect = 1);
EINT doSelect(MysqlConnScopedPtr& conn, const String& table, Json::Value& columns, const String& where);

// doSelect() 参数 columns 提供字段模板，
// 结果也通过 columns 传出第一条记录，值可分辨字符串或整数类型。
// 如要选出多条记录，通过额外第五个参数 result 传出 json 数组，
// 此时返回结果数组大小，0 表示没结果
// 不传 result 的版本，认为要选出一条记录，保存在 columns 中，无记录时返回错误
int doSelect(MysqlConnScopedPtr& conn, const String& table, const Json::Value& columns, const Json::Value& keys, Json::Value& result);
int doSelect(MysqlConnScopedPtr& conn, const String& table, const Json::Value& columns, const String& where, Json::Value& result);

} // namespace Sql
} // namespace Json


#endif /* end of include guard: SQLOPER_H__ */
