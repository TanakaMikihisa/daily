#!/usr/bin/env bash

set -euo pipefail

_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$_here/.."
repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

formatter_script="$_here/format_markdown.sh"
if [ ! -x "$formatter_script" ]; then
  echo "実行可能な整形スクリプトが見つかりません: $formatter_script" >&2
  exit 1
fi

# 変更のある *.md のうち、daily フォルダ直下だけを対象にする
# 例:
# - daily/2026-04-07.md             -> 2026-04-07.md
# - 研究室/daily/2026-04-06.md       -> 研究室/2026-04-06.md
#
# NOTE:
# git status --porcelain は非ASCIIパスをエスケープ表示することがあり、
# 文字列パターン判定が失敗しやすい。ここでは name-only 系を組み合わせる。
targets="$(
  {
    git -c core.quotepath=false diff --name-only -- '*.md'
    git -c core.quotepath=false diff --cached --name-only -- '*.md'
    git -c core.quotepath=false ls-files --others --exclude-standard -- '*.md'
  } | awk '!seen[$0]++'
)"

if [ -z "${targets//[[:space:]]/}" ]; then
  echo "daily フォルダ直下の変更された *.md はありません。"
  exit 0
fi

count=0
while IFS= read -r path; do
  [ -z "$path" ] && continue
  case "$path" in
    daily/*.md) ;;
    */daily/*.md) ;;
    *) continue ;;
  esac

  # 表示用ファイル名を組み立て
  # ルート daily はファイル名のみ
  # サブ daily は <parent>/<file>.md
  if [[ "$path" == daily/* ]]; then
    display_name="${path#daily/}"
  else
    parent="${path%%/daily/*}"
    filename="${path##*/}"
    display_name="${parent}/${filename}"
  fi

  if ! git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
    msg="☘️Add ${display_name}"
  else
    msg="✨Rewrite ${display_name}"
  fi

  "$formatter_script" "$path"
  git add -- "$path"
  git commit -m "$msg"
  count=$((count + 1))
done <<< "$targets"

if [ "$count" -eq 0 ]; then
  echo "daily フォルダ直下の変更された *.md はありません。"
  exit 0
fi

echo "完了: ${count} 件をコミットしました。"
