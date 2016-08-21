#include <iostream>
#include "stdio.h"

#include "CItemSelector.h"

using namespace std;

int main(int argc, char *argv[])
{
	CPrimarySelector<char> obj;
	
	obj.AddElement('A', 1);
	obj.AddElement('B', 1);
	obj.AddElement('C', 2);
	obj.AddElement('A', 1);
	obj.AddElement('D', 1);
	obj.AddElement('B', 2);
	obj.AddElement('E', 2);

	cout << "Content " << obj.GetSize() << " :";
	for (int i = 0; i < obj.GetSize(); ++i)
	{
		cout << obj.GetFirst(i) << " | ";
	}
	cout << endl;

	for (int i = 0; i < obj.GetSize(); ++i)
	{
		printf("%c[%d] ", obj.GetFirst(i), obj.GetWeight(i));
	}
	printf("\n");
	// B[3] C[2] A[2] E[2] D[1]

	return 0;
}
