#ifndef TESTSIZE_H__
#define TESTSIZE_H__

#include <stdint.h>

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

#endif /* end of include guard: TESTSIZE_H__ */
