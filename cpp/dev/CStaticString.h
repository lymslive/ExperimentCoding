#ifndef CSTATICSTRING_H__
#define CSTATICSTRING_H__

#include <cstring>
#include <stddef.h>

// 表示一个字符串的纯粹的结构体
// typedef StructString SStr
struct SStr
{
	size_t len;
	const char* str;

	SStr() : len(0), str(NULL) {}
	SStr(const char* pStr) : len(strlen(pStr)), str(pStr) {}
	SStr(const char* pStr, size_t iLength) : len(iLength), str(pStr) {}
};

// 静态字符串类，不申请额外保存空间
// 用户保证指针所批的字符串缓冲区生存空间长于本对象
// 例如适于表示字面字符串
// typedef CStaticString CStr
class CStr : protected SStr
{
public:
	CStr() {}
	CStr(const char* pStr) : SStr(pStr) {}
	CStr(const char* pStr, size_t iLength) : SStr(pStr, iLength) {}

	size_t length() const { return len; }

	// c_str() 与 c_end() 可当作迭代器使用
	const char* c_str() const { return str; }
	const char* c_end() const { return str + len; }
	char* begin() { return data(); }
	char* end() { return data() + len; }
	char* data() { return const_cast<char*>(str);}

	// 直接当成C字符串指针使用
	operator const char* () const { return str;}

	bool operator< (const CStr& that) const
	{
		return len < that.len || strcmp(str, that.str) < 0;
	}
	bool operator== (const CStr& that) const
	{
		return str == that.str || (len == that.len && strcmp(str, that.str) == 0);
	}
	bool operator> (const CStr& that) const { return that < *this; }
	bool operator<= (const CStr& that) const { return !(that < *this); }
	bool operator>= (const CStr& that) const { return !(*this < that); }
	bool operator!= (const CStr& that) const { return !(*this == that); }

	// 索引未检查越界，像原始字符指针使用
	char& operator[](size_t i) { return *(const_cast<char*>(str) + i); }
	const char& operator[](size_t i) const { return str[i]; }

};

#endif /* end of include guard: CSTATICSTRING_H__ */
