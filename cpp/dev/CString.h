#ifndef CSTRING_H__
#define CSTRING_H__

#include "CStaticString.h"

// 不可变字符串，当作字符串值使用，有独立的存储空间
// typedef CConstString CString
class CString : public CStr
{
public:
	// CString() {}
	CString(const char* pStr = NULL);
	CString(const CString& that);
	CString(const CStr& that);
	~CString() { _free(); len = 0; }

	CString& operator= (const CString& that);
	CString& operator= (const char* pthat);
	CString operator+ (const char* pthat);
	CString& operator+= (const char* pthat);

protected:
	char* _alloc(size_t n);
	void _free();
	void _copy(const char* pStr, size_t iLength);
};

// 用于构造可增长的字符串
// 成员变量 cap len str
class CStrbuf : public CString
{
public:
	// CStrbuf() : CString(), cap(0) {}
	CStrbuf(const char* pStr = NULL);
	CStrbuf(size_t nCap);
	CStrbuf(const CStrbuf& that);
	CStrbuf(const CStr& that);
	~CStrbuf() { cap = 0; }

	CStrbuf& operator<< (const char* pthat) { return *this += pthat; }
	CStrbuf& operator+= (const char* pthat);
	CStrbuf operator+ (const char* pthat);
	CStrbuf& operator= (const char* pthat);
	CStrbuf& operator= (const CStrbuf& that);

	// 扩展空间
	CStrbuf& reserve(size_t nCap);
	// 删除冗余空间，并将自己强转为基类返回，可另外指定截断长度
	CString* fixstr(size_t cutlen = 0);

	size_t capcity() const { return cap; }

private:
	void _append(const char* pStr, size_t iLength);
	void _realloc(size_t n);

private:
	size_t cap;
};


#endif /* end of include guard: CSTRING_H__ */
