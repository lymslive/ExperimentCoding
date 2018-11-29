#ifndef CSCALAR_H__
#define CSCALAR_H__

#include <stdint.h>
#include <stddef.h>

// CHString 增强版本，可表达一个字符串或数字标量
// 32 字节栈内小字符串，纯字符串最长 30 ，若同时存其所表示的数值，缩减 8 字节
// 长字符串扩展指针表示法：
// 8 字节指针，8 指针数值槽，长度、预留容量、引用共享数各 4 字节
// 头部 4 字节保存各种特征值，最大支持字符串约 4G。
class CScalar
{
public:
	CScalar();
	~CScalar();
	CScalar(const CScalar& that);
	CScalar& operator= (const CScalar& that);

	CScalar(const char* pStr);
	CScalar(int iValue);
	CScalar(double dValue);
	CScalar(uint64_t uValue);

	int HeadLen() { return large.head.biLen; }
	bool InHeap() { return HeadLen() > 30; }

	// 字符串接口
	size_t length() const;
	const char* c_str() const;
	const char* c_end() { return c_str() + length(); }
	char* begin() { return data(); }
	char* end() { return data() + length(); }
	char* data() { return const_cast<char*>(c_str());}

	// 字符串比较运算
	bool operator< (const CScalar& that) const;
	bool operator== (const CScalar& that) const;
	bool operator> (const CScalar& that) const { return that < *this; }
	bool operator<= (const CScalar& that) const { return !(that < *this); }
	bool operator>= (const CScalar& that) const { return !(*this < that); }
	bool operator!= (const CScalar& that) const { return !(*this == that); }

	// 字符串索引
	char& operator[](size_t i) { return data()[i]; }
	const char& operator[](size_t i) const { return c_str()[i]; }

	// 字符串增长
	CScalar& operator+= (const CScalar& that);
	CScalar& operator+ (const CScalar& that);
	CScalar& operator+ (const char* pStr);
	CScalar& operator<< (int iValue);
	CScalar& operator<< (double dValue);
	CScalar& operator<< (uint64_t UValue);

	// 数值运算
	CScalar& operator+ (int iValue) const;
	CScalar& operator+ (double dValue) const;
	CScalar& operator+ (uint64_t UValue) const;
	CScalar& operator- (int iValue) const;
	CScalar& operator- (double dValue) const;
	CScalar& operator- (uint64_t UValue) const;
	CScalar& operator* (int iValue) const;
	CScalar& operator* (double dValue) const;
	CScalar& operator* (uint64_t UValue) const;
	CScalar& operator/ (int iValue) const;
	CScalar& operator/ (double dValue) const;
	CScalar& operator/ (uint64_t UValue) const;

	// 类型转化
	operator const char* () const {return c_str(); }
	operator int () const;
	operator double () const;
	operator uint64_t () const;
	operator bool() const;

	// 类型定义
	enum EStorageType {
		STORAGE_UNDEFINED = 0,
		STORAGE_BOOL = 1,
		STORAGE_INT = 2,
		STORAGE_DOUBLE = 3,
		STORAGE_LONG_UINT = 4,
		STORAGE_ARRAY_IDX = 5,
		STORAGE_STRING_PTR = 6,
		STORAGE_STATIC_NUL = 7,
	};

	bool HasValue() const { return large.head.biType != STORAGE_UNDEFINED; }
	bool HasInt() const { return large.head.biType == STORAGE_INT || large.head.biType == STORAGE_LONG_UINT; }
	bool HasFloat() const { return large.head.biType == STORAGE_DOUBLE; }
	bool HasNumber() const { return HasInt() || HasFloat(); }
	static CScalar& Null();

private:
	void _free();
	char* _alloc(uint32_t iLength);

	// 内存布局模型
	union UValue {
		bool bValue;
		int iValue;
		double dValue;
		uint64_t uValue;
		size_t idx;
		void* ptr;
	};
	struct BitHead {
		uint8_t biLen : 5;
		uint8_t biType : 3;
	};
	struct LargeRep {
		BitHead head;
		uint8_t head1;
		uint8_t head2;
		uint8_t head3;
		uint32_t refcount;
		uint32_t capcity;
		uint32_t length;
		char* ptr;
		UValue val;
	};
	struct SmallRep {
		BitHead head;
		char data[32-1-8];
		UValue val;
	};

	union {
		char sdata[32];
		LargeRep large;
		SmallRep small;
	};
};

#endif /* end of include guard: CSCALAR_H__ */
