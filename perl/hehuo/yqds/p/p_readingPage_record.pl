$p_readingPage_record = <<EOF;
朗读录音
INPUT:
  chapterID => 章节
  chapterPage => 第几页
  audioFile => 上传的音频文件
  audioFrag => 属性第几个切分片段，索引从 0 开始
  audioFinal => 是否最后一个切分片段
OUPUT:
  // 原样返回
  chapterID => 章节
  chapterPage => 第几页
  audioFile => 上传的音频文件
  audioFrag => 属性第几个切分片段，索引从 0 开始
  audioFinal => 是否最后一个切分片段
  // 额外输出
  audioText => 识别文本
  scoreStar => 评分星级，是最后一个片段才有效
EOF

sub p_readingPage_record
{
	return jr() unless assert($gs->{pid}, "login first", "ERR_LOGIN", "Login first");
	return jr() unless assert($gr->{chapterID},"expcet argument: chapterID","ERR_ARGUMENT","缺少章节号");
	return jr() unless assert($gr->{chapterPage},"expcet argument: chapterPage","ERR_ARGUMENT","缺少页码");
	return jr() unless assert($gr->{audioFile},"expcet argument: audioFile","ERR_ARGUMENT","缺少音频文件");
	return jr() unless assert($gr->{audioFrag},"expcet argument: audioFrag","ERR_ARGUMENT","缺少音频分段");
	return jr() unless assert($gr->{audioFinal},"expcet argument: audioFinal","ERR_ARGUMENT","缺少音频结束标记");

	my $scoreStar = 0;
	$scoreStar = 3 if $gr->{audioFinal};
	my $audioText = "暂未识别";

	my $readingPage_doc = mdb()->get_collection("readingPage")->find_one({
			studentID => $gs->{pid},
			chapterID => $gr->{chapterID},
			chapterPage => $gr->{chapterPage},
		});

	if (!defined($readingPage_doc)) {
		# 新建记录
		$readingPage_doc = {
			_id => obj_id(),
			type => 'readingPage',
			studentID => $gs->{pid},
			chapterID => $gr->{chapterID},
			chapterPage => $gr->{chapterPage},
			fragCount => 1,
			readingFrag => [{
					audioFrag => $gr->{audioFrag}, 
					audioFile => $gr->{audioFile},
					audioText => $audioText,
				}],
			scoreStar => 0,
		};
	}
	else {
		my $readFrag_new = {
			audioFrag => $gr->{audioFrag}, 
			audioFile => $gr->{audioFile},
			audioText => $audioText,
		};
		push(@{$readingPage_doc->{readingFrag}}, $readingPage_new);
		$readingPage_doc->{fragCount} += 1;
		$readingPage_doc->{scoreStar} = 3 if $gr->{audioFinal};
	}
	obj_write($readingPage_new);

	return jr({
			chapterID => $gr->{chapterID},
			chapterPage => $gr->{chapterPage},
			audioFile => $gr->{audioFile},
			audioFrag => $gr->{audioFrag},
			audioFinal => $gr->{audioFinal},
			audioText => $audioText,
			scoreStar => $scoreStar,
		});
}

