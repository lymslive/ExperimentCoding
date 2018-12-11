#include <cstdio>

int main(int argc, char *argv[])
{
	int a = 1, b = 2, c = 5;
	int re = a > 3 ? a : b > 3 ? b : c;
	printf("re = %d\n", re); // --> 5

	a = 1, b = 4, c = 5;
	re = a > 3 ? a : b > 3 ? b : c;
	printf("re = %d\n", re); // --> 4

	a = 10, b = 4, c = 5;
	re = a > 3 ? a : b > 3 ? b : c;
	printf("re = %d\n", re); // --> 10

	a = 10, b = 4, c = 5;
	re = (a > 3) ? a : (b > 3 ? b : c);
	printf("re = %d\n", re); // --> 10

	// -->
	// 三元运算符可以层叠

	return 0;
}
