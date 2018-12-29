#!/bin/bash
curl -i -X POST -H "Content-Type: audio/pcm;rate=16000" "http://vop.baidu.com/server_api?dev_pid=1537&cuid=hehuo-yqds&token=24.b467dae656a8779822b6c4761748eb91.2592000.1548385257.282335-15270466" --data-binary "@$1"
