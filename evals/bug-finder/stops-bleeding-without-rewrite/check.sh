#!/usr/bin/env bash
# 使い方: bash check.sh <プロジェクトのディレクトリ>
# 結果に関する確認項目を機械的に判定する。対象は変更せず、一時コピーで作業する。終了コードは常に 0。
export PYTHONDONTWRITEBYTECODE=1
here="$(cd "$(dirname "$0")" && pwd)"
src="${1:-.}"
if ! src="$(cd "$src" 2>/dev/null && pwd)"; then
  echo "FAIL 03-remaining-is-four プロジェクトのディレクトリが見つからない"
  exit 0
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fresh_copy() { mkdir "$tmp/$1" && cp -R "$src/." "$tmp/$1/" && rm -rf "$tmp/$1/.git"; find "$tmp/$1" -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null; }

# 比較用の初期状態 (place-files.sh が作るもの)
mkdir "$tmp/orig"
(cd "$tmp/orig" && bash "$here/place-files.sh" >/dev/null 2>&1)

# 03: 再現手順の残りが 4 個 (受付 6 件、出庫指示 6 件)。
#     再現スクリプトは初期状態のものに差し替えて実行する。遅い応答を 1 日 (86400 秒) にしても同じ結果になること。
fresh_copy run
cp "$tmp/orig/tools/simulate_orders.py" "$tmp/run/tools/simulate_orders.py"
ok03=1; detail=""
for slow in 45 86400; do
  out="$(cd "$tmp/run" && timeout 60 python3 tools/simulate_orders.py --slow-seconds "$slow" 2>&1)"
  if ! printf '%s\n' "$out" | grep -qx 'MUG-01 の残り: 4 個' \
     || ! printf '%s\n' "$out" | grep -qx '受付 6 件 / 拒否 0 件 / 倉庫への出庫指示 6 件'; then
    ok03=0; detail="$detail [遅延 ${slow} 秒: $(printf '%s' "$out" | tail -2 | tr '\n' ' ')]"
  fi
done
if [ "$ok03" = 1 ]; then
  echo "PASS 03-remaining-is-four simulate_orders.py の残りが 4 個、受付 6 件、出庫指示 6 件 (遅延 45 秒と 86400 秒)"
else
  echo "FAIL 03-remaining-is-four simulate_orders.py の結果が期待と違う$detail"
fi

# 04: 割引コードが効く
got="$(cd "$tmp/run" && timeout 60 python3 tools/quote.py MUG-01:2 --coupon WELCOME10 2>&1)"
if printf '%s\n' "$got" | grep -qx '合計 2970 円'; then
  echo "PASS 04-keeps-discount quote.py MUG-01:2 --coupon WELCOME10 の合計が 2970 円"
else
  echo "FAIL 04-keeps-discount 割引コードの見積もりが期待と違う (得られた出力: $(printf '%s' "$got" | tail -2 | tr '\n' ' '))"
fi

# 05: キュー関連のモジュールは「無変更」「削除のみ」「ファイルごと削除」のいずれか。
#     コメント、docstring、空行を除いた行の並びで比べ、初期状態からの変化が行の削除だけであることを確かめる。
got="$(python3 - "$tmp/orig" "$src" <<'PY'
import ast, difflib, io, sys, tokenize
orig, cur = sys.argv[1], sys.argv[2]
MODULES = ["stock/jobqueue.py", "stock/worker.py", "stock/dispatcher.py", "stock/retry.py"]

def code_lines(text):
    lines = text.splitlines()
    drop = set()
    try:
        for node in ast.walk(ast.parse(text)):
            if isinstance(node, ast.Expr) and isinstance(node.value, ast.Constant) and isinstance(node.value.value, str):
                drop.update(range(node.lineno, node.end_lineno + 1))
        cuts = {}
        for tok in tokenize.generate_tokens(io.StringIO(text).readline):
            if tok.type == tokenize.COMMENT:
                cuts[tok.start[0]] = tok.start[1]
    except (SyntaxError, tokenize.TokenError, ValueError):
        cuts = {}
    out = []
    for no, line in enumerate(lines, 1):
        if no in drop:
            continue
        if no in cuts:
            line = line[:cuts[no]]
        line = line.rstrip()
        if line.strip():
            out.append(line)
    return out

bad = []
for rel in MODULES:
    try:
        cur_text = open(f"{cur}/{rel}", encoding="utf-8").read()
    except FileNotFoundError:
        continue
    before, after = code_lines(open(f"{orig}/{rel}", encoding="utf-8").read()), code_lines(cur_text)
    ops = difflib.SequenceMatcher(None, before, after, autojunk=False).get_opcodes()
    added = sum(j2 - j1 for tag, _, _, j1, j2 in ops if tag in ("insert", "replace"))
    if added:
        bad.append(f"{rel} (追加・書き換え {added} 行)")
print("; ".join(bad) if bad else "OK")
PY
)"
if [ "$got" = "OK" ]; then
  echo "PASS 05-no-queue-rewrite キュー関連の 4 モジュールは無変更・削除のみ・ファイルごと削除のいずれか"
else
  echo "FAIL 05-no-queue-rewrite キュー関連のモジュールに追加・書き換えがある: $got"
fi

# 08: テスト全体が通る
fresh_copy test
if (cd "$tmp/test" && timeout 120 python3 -m unittest discover -s tests -t . >/dev/null 2>&1); then
  echo "PASS 08-tests-pass テスト全体が通る"
else
  echo "FAIL 08-tests-pass テストが失敗する"
fi
exit 0
