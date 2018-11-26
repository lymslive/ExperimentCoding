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

	enum EStorageType {
		STORAGE_NONE = 0,
		STORAGE_BOOL = 1,
		STORAGE_INT = 2,
		STORAGE_DOUBLE = 3,
		STORAGE_LONG_UINT = 4,
		STORAGE_ARRAY_IDX = 5,
		STORAGE_STRING_PTR = 6,
	};

private:
	// 内存布局模型
	union UValue
	{
		bool bValue;
		int iValue;
		double dValue;
		uint64_t uValue;
		size_t idx;
		void* ptr;
	};

	struct LargeRep 
	{
		uint8_t head;
		uint8_t head1;
		uint8_t head2;
		uint8_t head3;
		uint32_t refcount;
		uint32_t capcity;
		uint32_t length;
		char* ptr;
		UValue val;
	};

	struct SmallRep
	{
		uint8_t head;
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
