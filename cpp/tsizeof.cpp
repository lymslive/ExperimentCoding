#include <iostream>
// #include <cstdint>
#include <stdint.h>

struct Stu1
{
	char sex;
	int id;
	float height;
};

struct Stu2
{
	int id;
	char sex;
	float height;
};

struct Stu3
{
	int id;
	float height;
	char sex;
};

struct Foo1
{
	char c1;
	short s;
	char c2;
	int i;
};

struct Foo2
{
	char c1;
	char c2;
	short s;
	int i;
};

int main()
{
	const char ca[] = "hello, world!";
	const char *p1 = "hello, world!";
	const char *p2[] = { "hello", "world" };
	unsigned char matrix[3][3];

	std::cout << "sizeof(ca): " << sizeof(ca) << std::endl;
	std::cout << "sizeof(p1): " << sizeof(p1) << std::endl;
	std::cout << "sizeof(p2):" << sizeof(p2) << std::endl;
	std::cout << "sizeof(matrix):" << sizeof(matrix) << std::endl;
	std::cout << "sizeof(Stu1):" << sizeof(Stu1) << std::endl;
	std::cout << "sizeof(Stu2):" << sizeof(Stu2) << std::endl;
	std::cout << "sizeof(Stu3):" << sizeof(Stu3) << std::endl;
	std::cout << "sizeof(Foo1):" << sizeof(Foo1) << std::endl;
	std::cout << "sizeof(Foo2):" << sizeof(Foo2) << std::endl;

	std::cout << "sizeof(char):" << sizeof(char) << std::endl;
	std::cout << "sizeof(short):" << sizeof(short) << std::endl;
	std::cout << "sizeof(int):" << sizeof(int) << std::endl;
	std::cout << "sizeof(long):" << sizeof(long) << std::endl;
	std::cout << "sizeof(long long):" << sizeof(long long) << std::endl;
	std::cout << "sizeof(float):" << sizeof(float) << std::endl;
	std::cout << "sizeof(double):" << sizeof(double) << std::endl;
	std::cout << "sizeof(long double):" << sizeof(long double) << std::endl;

	std::cout << "sizeof(size_t):" << sizeof(size_t) << std::endl;
	std::cout << "sizeof(void*):" << sizeof(void*) << std::endl;
	std::cout << "sizeof(char*):" << sizeof(char*) << std::endl;
	std::cout << "sizeof(int*):" << sizeof(int*) << std::endl;
	std::cout << "sizeof(double*):" << sizeof(double*) << std::endl;

	std::cout << "sizeof(uint8_t):" << sizeof(uint8_t) << std::endl;
	std::cout << "sizeof(uint16_t):" << sizeof(uint16_t) << std::endl;
	std::cout << "sizeof(uint32_t):" << sizeof(uint32_t) << std::endl;
	std::cout << "sizeof(uint64_t):" << sizeof(uint64_t) << std::endl;
	std::cout << "sizeof(int8_t):" << sizeof(int8_t) << std::endl;
	std::cout << "sizeof(int16_t):" << sizeof(int16_t) << std::endl;
	std::cout << "sizeof(int32_t):" << sizeof(int32_t) << std::endl;
	std::cout << "sizeof(int64_t):" << sizeof(int64_t) << std::endl;
}
