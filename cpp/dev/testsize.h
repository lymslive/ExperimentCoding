#ifndef TESTSIZE_H__
#define TESTSIZE_H__

#include <stdint.h>
#include <stddef.h>

struct HStrRep
{
	uint8_t head;
	uint8_t bStatic;
	uint8_t bConst;
	uint8_t bDummy;
	uint32_t length;
	char* ptr;
};

class CHString
{
public:
	union {
		HStrRep rep_;
		char stack_[16];
	};
};

struct SStrRep
{
	size_t len;
	char* str;
};

struct SStrRep1
{
	int len;
	char* str;
};

struct SStrRep2
{
	char* str;
	int len;
};

class CScalar
{
public:
	union UValue
	{
		bool bValue;
		int iValue;
		long lValue;
		float fValue;
		double dValue;
		uint64_t uValue;
	};

	struct ScalarRep 
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
		ScalarRep sbig_;
		SmallRep small_;
		char sdata_[32];
	};
};
#endif /* end of include guard: TESTSIZE_H__ */
