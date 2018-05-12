测试多文件 perl 脚本用法。如果不想将项目局部功能模块放入全局 @INC

require 与 use

require 最好用引号全文件名，可 .pl 或 .pm
use 引用 .pm 模块名，裸词，不含后缀

可使用被引入的 sub，但不能使用其内的 my 变量。

如果被引入文件用了 package，得用 packname::sub 全名使用。
