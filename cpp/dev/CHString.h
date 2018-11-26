#ifndef CHSTRING_H__
#define CHSTRING_H__

#include <stdint.h>
#include <stddef.h>

// 16 字节栈内小字符串按前缀字符串保存，实际最大 14 长度。
// 更长字符串扩展字符串指针：
// 尾部 8 字节指针，4 字节表示字符串长度，最长约 4G
// 头部 4 字节用以表征字符串各种特性。
// 扩展字符串只申请一次内存，不可再变长。
class CHString
{
public:
	CHString();
	CHString(const char* pStr);
	CHString(const CHString& that);
	~CHString();

	int HeadLen();
	bool InStack() { return HeadLen() <= 14; }
	bool InHeap() { return !InStack(); }

	size_t length() const;
	const char* c_str() const;
	const char* c_end() { return c_str() + length(); }
	char* begin() { return data(); }
	char* end() { return data() + len; }
	char* data() { return const_cast<char*>(c_str());}

	bool operator< (const CHString& that) const;
	bool operator== (const CHString& that) const;
	bool operator> (const CHString& that) const { return that < *this; }
	bool operator<= (const CHString& that) const { return !(that < *this); }
	bool operator>= (const CHString& that) const { return !(*this < that); }
	bool operator!= (const CHString& that) const { return !(*this == that); }

	char& operator[](size_t i) { return data()[i]; }
	const char& operator[](size_t i) const { return c_str()[i]; }

	CHString& operator= (const CHString& that);

	// 末尾 8 字节扩展指针，也可以不存指针，存放其他值
	// 非栈内小字符串时，用第2字节表示值类型
	enum EStorageType {
		STORAGE_STRING_PTR = 0,
		STORAGE_ARRAY_IDX = 1,
		STORAGE_INT = 2,
		STORAGE_DOUBLE = 3,
		STORAGE_LONG_UINT = 4,
	};

	// 获取字符串指针以外的值，返回错误码，传出参数
	int GetValue(size_t& outIdx);
	int GetValue(int& outInt);
	int GetValue(double& outVal);
	int GetValue(uint64_t& outVal);
	int SetValue(size_t setIdx);
	int SetValue(int setInt);
	int SetValue(double setVal);
	int SetValue(uint64_t setVal);

private:
	void _free();
	char* _alloc(uint32_t iLength);

	// 内存布局模型
	union UValue
	{
		char* ptr;
		size_t idx;
		int iValue;
		double dValue;
		uint64_t uValue;
	};
	struct HStrRep
	{
		uint8_t head;
		uint8_t bType;
		uint8_t bStatic;
		uint8_t bConst;
		uint32_t len;
		UValue val;
	};
	union {
		char sdata[16];
		HStrRep large;
	};
};

#endif /* end of include guard: CHSTRING_H__ */
