ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.PHONY: all

# 既定: daily 配下の変更 Markdown を整形してからコミットする
all:
	"$(ROOT)scripts/deploy_daily.sh"
