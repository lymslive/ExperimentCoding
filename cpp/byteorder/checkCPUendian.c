#include "stdlib.h"
#include "stdio.h"

#include <arpa/inet.h>

/* 小端返回true */
int checkCPUendian()
{
    union{
	unsigned int a;
	unsigned char b;
    } c;

    c.a = 1;
    return 1 == c.b;
}

int main(int argc, char *argv[])
{
    if (checkCPUendian())
    {
        printf("Little Endian\n");
    }
    else
    {
	printf("Big Endian\n");
    }

    int a = 12345678;
    printf("%d\t%d\n", a, htonl(a));
    printf("%d\t%d\n", a, ntohl(a)); /* 与 htonl 一样效果 */
    printf("%d\t%d\n", a, htonl(htonl(a))); /* 可逆 */
   
    int b = 0x12345678;
    printf("%d\t%d\n", b, htonl(b));
    printf("%x\t%x\n", b, htonl(b));
    printf("%x\t%x\n", b, ntohl(b));
    printf("%x\t%x\n", b, htonl(htonl(b)));
   
    return 0;
}
