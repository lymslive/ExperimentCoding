#include "ErrorMgr.h"
#include <commonutil/api_logger.h>

namespace TFBError
{

EMSG CErrorMgr::GetErrstr(EINT error, EMSG pDefault/* = NULL*/)
{
	auto it = m_mapErrstr.find(error);
	if (it == m_mapErrstr.end())
	{
		return pDefault;
	}
	return it->second.c_str();
}

EINT CErrorMgr::LoadError(MysqlConnScopedPtr& conn, const char* group/* = NULL*/)
{
	std::string strGroup(ERROR_COMM);
	if (group != NULL) {
		strGroup += ",";
		strGroup += group;
	}

	log_trace("to load error table within service group IN(%s)", strGroup.c_str());
	ScopedPtr<mysql::ResultSet> rs;
	rs.reset(conn->query("SELECT F_error, F_errstr From %s WHERE F_service IN(%s)",
				ERROR_TABLE, strGroup.c_str()));
	if (!rs)
	{
		return NOK;
	}

	error_t oneErr;
	while (rs->next())
	{
		oneErr.error = rs->getInt32(0);
		oneErr.errstr = rs->getString(1);
		m_mapErrstr[oneErr.error] = oneErr.errstr;
	}

	log_trace("load error count[%d]", m_mapErrstr.size());

	return OK;
}

CErrorMgr& CErrorMgr::Instance()
{
	static CErrorMgr s;
	return s;
}

EINT Init(MysqlConnScopedPtr& conn, const char* group/* = NULL*/)
{
	return CErrorMgr::Instance().LoadError(conn, group);
}

EMSG GetErrstr(EINT error, EMSG pDefault/* = NULL*/)
{
	return CErrorMgr::Instance().GetErrstr(error, pDefault);
}

}
