#!/usr/bin/env bash

set -euo pipefail

_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$_here/.."
repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if [ "$#" -gt 0 ]; then
  targets=("$@")
else
  targets=()
  while IFS= read -r line; do
    [ -n "$line" ] && targets+=("$line")
  done < <(
    {
      git -c core.quotepath=false ls-files -- '*.md'
      git -c core.quotepath=false ls-files --others --exclude-standard -- '*.md'
    } | awk '!seen[$0]++'
  )
fi

if [ "${#targets[@]}" -eq 0 ]; then
  echo "対象の *.md が見つかりませんでした。"
  exit 0
fi

for file in "${targets[@]}"; do
  if [ "${file##*/}" = "template.md" ]; then
    continue
  fi

  if [ ! -f "$file" ]; then
    echo "スキップ: ファイルが存在しません: $file" >&2
    continue
  fi

  tmp="$(mktemp)"

  awk '
    function is_heading(line) {
      return (line ~ /^#{1,6}[[:space:]]+/)
    }

    function heading_level(line) {
      if (match(line, /^#+/))
        return RLENGTH
      return 999
    }

    function is_blank(line,    t) {
      t = line
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
      return (length(t) == 0)
    }

    # この見出しのブロック終端（同じか上位の見出しの直前、または EOF の次）
    function next_section_end(lines, n, i, lev,    j, hl) {
      j = i + 1
      while (j <= n) {
        if (is_heading(lines[j])) {
          hl = heading_level(lines[j])
          if (hl <= lev)
            return j
        }
        j++
      }
      return n + 1
    }

    # 指定レベルの見出しで、セクション内が空（空白行のみ）なら見出しごと削除
    function strip_empty_at_level(lines, n, tl,    newlines, ni, i, j, k, hc, lev) {
      ni = 0
      i = 1
      while (i <= n) {
        if (!is_heading(lines[i]) || heading_level(lines[i]) != tl) {
          newlines[++ni] = lines[i]
          i++
          continue
        }
        lev = tl
        j = next_section_end(lines, n, i, lev)
        hc = 0
        for (k = i + 1; k < j; k++) {
          if (!is_blank(lines[k])) {
            hc = 1
            break
          }
        }
        if (!hc)
          i = j
        else {
          for (k = i; k < j; k++)
            newlines[++ni] = lines[k]
          i = j
        }
      }
      for (k = 1; k <= ni; k++)
        lines[k] = newlines[k]
      return ni
    }

    function strip_all_empty_sections(lines, n,    before, tl) {
      do {
        before = n
        for (tl = 6; tl >= 1; tl--)
          n = strip_empty_at_level(lines, n, tl)
      } while (n < before)
      return n
    }

    function emit(line) {
      out[++out_count] = line
    }

    function emit_blank_once() {
      if (out_count == 0) return
      if (out[out_count] != "") emit("")
    }

    {
      raw[NR] = $0
    }

    END {
      nr = NR
      if (nr == 0)
        exit 0

      nr = strip_all_empty_sections(raw, nr)

      out_count = 0
      force_blank_after_heading = 0

      for (idx = 1; idx <= nr; idx++) {
        line = raw[idx]

        if (line ~ /^#{1,6}[[:space:]]+/) {
          emit_blank_once()
          emit(line)
          force_blank_after_heading = 1
          continue
        }

        if (force_blank_after_heading) {
          emit_blank_once()
          force_blank_after_heading = 0
        }

        if (line == "") {
          emit_blank_once()
        } else {
          emit(line)
        }
      }

      while (out_count > 0 && out[out_count] == "") {
        out_count--
      }

      for (i = 1; i <= out_count; i++) {
        print out[i]
      }
    }
  ' "$file" > "$tmp"

  mv "$tmp" "$file"
  echo "整形完了: $file"
done
