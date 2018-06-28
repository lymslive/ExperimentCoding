# 代码辅助生成的 perl 过滤脚本使用

应用于标准输入输出的 perl 脚本，可在 vim 选择模式下调用，作为过滤工具使用。

# proto/xml

0) proto 的 snip 片断预生成，cmdid 宏暂设为 0，但开始最少定义一个值大于0的宏
0) macronum.pl 为 cmdid 顺序编号
0) bodyclip.pl 生成插入 proto_cs.xml 中的 <entry> 条目
0) zonemsgc.pl 去生成的对应 proto_cs_xxx.h 文件，为每个 cmdid 宏id 生成回调函数模板

# resource/xml

0) tabconf.pl 为每个配置表结构体生成 TabNamesDef.h 中的宏定义
0) tabload.pl 在 TabNamesDef.h 文件中为每条宏定义，生成初始化 load 语句

# 错误码输出
0) errtab.pl 将 svr_err.h 中的错误码导出文本配置表片断
