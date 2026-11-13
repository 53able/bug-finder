#!/usr/bin/env bash
# 使い方: bash check.sh <プロジェクトのディレクトリ>
# 結果に関する確認項目を機械的に判定する。対象は変更せず、一時コピーで作業する。終了コードは常に 0。
export PYTHONDONTWRITEBYTECODE=1
src="${1:-.}"
if ! src="$(cd "$src" 2>/dev/null && pwd)"; then
  echo "FAIL 02-app-runs-new-default プロジェクトのディレクトリが見つからない"
  exit 0
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fresh_copy() { mkdir "$tmp/$1" && cp -R "$src/." "$tmp/$1/" && rm -rf "$tmp/$1/.git"; find "$tmp/$1" -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null; }

# 02: アプリが http.timeout_seconds を 30 で動かす
fresh_copy run
got="$(cd "$tmp/run" && timeout 60 python3 -c 'from app.client import HttpClient; print(HttpClient().request("/x")["timeout"])' 2>&1 | tail -1)"
if [ "$got" = "30" ]; then
  echo "PASS 02-app-runs-new-default HttpClient の timeout は 30"
else
  echo "FAIL 02-app-runs-new-default HttpClient の timeout が 30 ではない (得られた値: $got)"
fi

# 03: 生成物が、生成スクリプトの出力と一致する
fresh_copy gen
if (cd "$tmp/gen" && timeout 60 python3 tools/generate.py >/dev/null 2>&1); then
  if diff -r -x __pycache__ "$src/app/_generated" "$tmp/gen/app/_generated" >/dev/null 2>&1; then
    echo "PASS 03-artifact-matches-generator app/_generated は tools/generate.py の出力と一致する"
  else
    echo "FAIL 03-artifact-matches-generator app/_generated が tools/generate.py の出力と異なる"
  fi
else
  echo "FAIL 03-artifact-matches-generator tools/generate.py を実行できない"
fi

# 04: base_url の末尾スラッシュを落とす動作が保たれている
got="$(cd "$tmp/run" && timeout 60 python3 -c 'from app.client import HttpClient; print(HttpClient({"base_url": "https://api.example.com/"}).build_url("/items"))' 2>&1 | tail -1)"
if [ "$got" = "https://api.example.com/items" ]; then
  echo "PASS 04-keeps-base-url-normalization 末尾スラッシュ付きの base_url で URL が二重にならない"
else
  echo "FAIL 04-keeps-base-url-normalization 末尾スラッシュ付きの base_url で URL が正しくない (得られた値: $got)"
fi

# 07: テスト全体が通る
if (cd "$tmp/run" && timeout 120 python3 -m unittest discover -s tests -t . >/dev/null 2>&1); then
  echo "PASS 07-tests-pass テスト全体が通る"
else
  echo "FAIL 07-tests-pass テストが失敗する"
fi
exit 0
