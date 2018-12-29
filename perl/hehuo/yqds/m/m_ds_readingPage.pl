$man_ds_readingPage = <<EOF;
朗读分页表

_id:
studentID: 学生号
chapterID: 章ID
chapterPage: 页码
fragCount: 录音分片数量
readingFrag:[
	audioFrag: 录音分片索引，0 开始
	audioFile: 录音文件
	audioText: 识别的录音
]
scoreStar: 评分
EOF
