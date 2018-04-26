#ifndef UNIONSTRUCT_H__
#define UNIONSTRUCT_H__

struct StructA
{
	int a;
};

struct StructB
{
	int b;
};

struct StructC
{
	int c;
};

union UStruct
{
	StructA A;
	StructB B;
	StructC C;
};

#endif /* end of include guard: UNIONSTRUCT_H__ */
