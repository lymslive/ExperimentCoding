#include "testsize.h"
#include "stdio.h"
#include "string.h"

int main(int argc, char *argv[])
{
	CHString hstr;
	printf("sizeof(HStrRep) = %d\n", sizeof(HStrRep));
	printf("sizeof(CHString) = %d\n", sizeof(CHString));
	printf("sizeof(hstr) = %d\n", sizeof(hstr));
	printf("sizeof(hstr.rep_) = %d\n", sizeof(hstr.rep_));
	printf("sizeof(hstr.stack_) = %d\n", sizeof(hstr.stack_));

	hstr.rep_.head = 7;
	strcpy(hstr.stack_+1, "abcdefg");
	printf("withhead: %s[%d]\n", hstr.stack_, strlen(hstr.stack_));
	printf("withouthead: %s[%d]\n", hstr.stack_+1, strlen(hstr.stack_+1));

	printf("sizeof(SStrRep) = %d\n", sizeof(SStrRep));
	printf("sizeof(SStrRep1) = %d\n", sizeof(SStrRep1));
	printf("sizeof(SStrRep2) = %d\n", sizeof(SStrRep2));

	CScalar sc;
	printf("sizeof(CScalar) = %d\n", sizeof(CScalar));
	printf("sizeof(sc) = %d\n", sizeof(sc));
	printf("sizeof(sc.sbig_) = %d\n", sizeof(sc.sbig_));
	printf("sizeof(sc.small_) = %d\n", sizeof(sc.small_));
	printf("sizeof(sc.sdata_) = %d\n", sizeof(sc.sdata_));
	printf("sizeof(sc.sbig_.val) = %d\n", sizeof(sc.sbig_.val));
	printf("sizeof(sc.small_.val) = %d\n", sizeof(sc.small_.val));
	return 0;
}
