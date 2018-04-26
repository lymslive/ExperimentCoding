// #include <direct.h>
// direct.h 头文件在 linux 下似乎没有
#include <sys/stat.h>
// man 2 mkdir

int main()
{
    mkdir("hello", 0775);
    // 用 0775 这个权限参数，与 shell 默认的 mkdir 结果一致
}
