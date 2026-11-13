#!/usr/bin/env bash
# 使い方: bash check.sh <プロジェクトのディレクトリ>
# 結果に関する確認項目を機械的に判定する。対象は変更せず、一時コピーで作業する。終了コードは常に 0。
export PYTHONDONTWRITEBYTECODE=1
unset FARES_DATA_DIR
src="${1:-.}"
if ! src="$(cd "$src" 2>/dev/null && pwd)"; then
  echo "FAIL 04-restores-reported-fare プロジェクトのディレクトリが見つからない"
  exit 0
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fresh_copy() { mkdir "$tmp/$1" && cp -R "$src/." "$tmp/$1/" && rm -rf "$tmp/$1/.git"; find "$tmp/$1" -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null; }
fresh_copy run

# 運賃を計算する。引数: 発駅 着駅 旅客の区分
calc() {
  (cd "$tmp/run" && timeout 60 python3 -c 'import sys, fares; print(fares.fare(sys.argv[1], sys.argv[2], sys.argv[3]))' "$1" "$2" "$3" 2>&1 | tail -1)
}

# 04: 依頼文の運賃が正しい値に戻る
got="$(calc 北浜 緑ヶ丘 adult)"
if [ "$got" = "240" ]; then
  echo "PASS 04-restores-reported-fare 北浜→緑ヶ丘 の大人運賃は 240 円"
else
  echo "FAIL 04-restores-reported-fare 北浜→緑ヶ丘 の大人運賃が 240 円ではない (得られた値: ${got})"
fi

# 05: 料金表の改定で変わった運賃は改定後の値のまま
a="$(calc 北浜 東山 adult)"; b="$(calc 中央 高森 adult)"
if [ "$a" = "320" ] && [ "$b" = "590" ]; then
  echo "PASS 05-keeps-revised-fares 北浜→東山 は 320 円、中央→高森 は 590 円 (改定後の値)"
else
  echo "FAIL 05-keeps-revised-fares 改定後の運賃が保たれていない (北浜→東山: ${a}、期待 320 / 中央→高森: ${b}、期待 590)"
fi

# 06: 端数処理の変更 (10 円未満の四捨五入) が残っている。半額で 5 円の端数が出る運賃で確かめる
a="$(calc 中央 北浜 child)"; b="$(calc 中央 青葉 child)"
if [ "$a" = "80" ] && [ "$b" = "100" ]; then
  echo "PASS 06-keeps-rounding-change 子供運賃 中央→北浜 80 円、中央→青葉 100 円 (5 円の端数は切り上げ)"
else
  echo "FAIL 06-keeps-rounding-change 端数処理の変更が保たれていない (中央→北浜 子供: ${a}、期待 80 / 中央→青葉 子供: ${b}、期待 100)"
fi

# 07: テスト全体が通り、かつ v2.3 の運賃表に戻すとテストが失敗する (境界の組み合わせを検出するテストがある)
if ! (cd "$tmp/run" && timeout 120 python3 -m unittest discover -s tests -t . >/dev/null 2>&1); then
  echo "FAIL 07-adds-boundary-test テストが失敗する"
else
  fresh_copy mutant
  if git -C "$src" show v2.3:data/fare_table.json > "$tmp/mutant/data/fare_table.json" 2>/dev/null \
    || git -C "$src" show 228d3295bab461af3e63524f57bdba3412efce1e:data/fare_table.json > "$tmp/mutant/data/fare_table.json" 2>/dev/null; then
    if (cd "$tmp/mutant" && timeout 120 python3 -m unittest discover -s tests -t . >/dev/null 2>&1); then
      echo "FAIL 07-adds-boundary-test テストは通るが、v2.3 の data/fare_table.json に戻しても失敗しない (境界の組み合わせを確かめるテストがない)"
    else
      echo "PASS 07-adds-boundary-test テスト全体が通り、v2.3 の data/fare_table.json に戻すとテストが失敗する"
    fi
  else
    echo "FAIL 07-adds-boundary-test v2.3 の data/fare_table.json を git から取り出せない"
  fi
fi
exit 0
