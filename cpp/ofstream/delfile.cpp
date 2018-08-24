#include <string>
#include <fstream>
#include <iostream>

int main(int argc, char *argv[])
{
	std::ofstream outfile;
	outfile.open("out.log", std::ios_base::app);

	std::string str;
	while (std::cin >> str)
	{
		std::cout << "CIN READ: " << str << std::endl;
		outfile << str << '\n';
		outfile.flush();
		if (outfile.good() == false)
		{
			std::cerr << "output file fail!" << std::endl;
		}
	}
	std::cout << "CIN END: " << std::endl;
	return 0;
}
