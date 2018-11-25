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
	return 0;
}
