#include <iostream>

struct Stu
{
	int id;
	char sex;
	float height;
};

int main()
{
	const char *p1 = "hello, world!";
	const char *p2[] = { "hello", "world" };
	unsigned char matrix[3][3];

	std::cout << "sizeof(p1): " << sizeof(p1) << std::endl;
	std::cout << "sizeof(p2):" << sizeof(p2) << std::endl;
	std::cout << "sizeof(matrix):" << sizeof(matrix) << std::endl;
	std::cout << "sizeof(Stu):" << sizeof(Stu) << std::endl;
}
