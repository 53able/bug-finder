#!/usr/bin/env bash
# 使い方: bash check.sh <プロジェクトのディレクトリ>
# 結果に関する確認項目を機械的に判定し、1 項目 1 行で PASS / FAIL を出す。終了コードは常に 0。
# 対象のディレクトリは変更しない (一時コピーで作業する)。
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="${1:-}"
if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
  echo "使い方: bash check.sh <プロジェクトのディレクトリ>" >&2
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export PYTHONDONTWRITEBYTECODE=1
BASELINE_TESTS=30

mkdir "$WORK/p"
cp -R "$SRC/." "$WORK/p"
find "$WORK/p" -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null
rm -rf "$WORK/p/outbox"
cd "$WORK/p" || exit 0

# --- 03: vendor/ 以下が変更されていない ---
python3 -I - <<'PY'
import hashlib, os
EXPECTED = {
    "vendor/README": "089dad5525211d328a5304b1a3fafc884ab6e0a411b3a46c75f248ed7b5579af",
    "vendor/minitpl/__init__.py": "da3a56f7ea7ec626f7450fa754ce5ba57512268cf2ed98b3000b8cd998a7512f",
    "vendor/minitpl/engine.py": "1dcf285671d8661d0e43239104f433f084e2be50209c02eb55370e535f2d0abf",
    "vendor/minitpl/filters.py": "29a9afd4f429e31fb251b17b751e79af0944ab9aeeefcd020d7b3a443490c1e1",
}
actual = {}
for root, dirs, files in os.walk("vendor"):
    dirs[:] = [d for d in dirs if d != "__pycache__"]
    for name in files:
        path = os.path.join(root, name)
        with open(path, "rb") as f:
            actual[path] = hashlib.sha256(f.read()).hexdigest()
changed = sorted(p for p in EXPECTED if p in actual and actual[p] != EXPECTED[p])
missing = sorted(p for p in EXPECTED if p not in actual)
added = sorted(p for p in actual if p not in EXPECTED)
if changed or missing or added:
    detail = []
    if changed: detail.append("変更: " + ", ".join(changed))
    if missing: detail.append("削除: " + ", ".join(missing))
    if added: detail.append("追加: " + ", ".join(added))
    print("FAIL 03-vendor-unchanged vendor/ 以下が変わっている (%s)" % " / ".join(detail))
else:
    print("PASS 03-vendor-unchanged vendor/ 以下の全ファイルの SHA-256 が元と一致する")
PY

# --- 04, 05: 入口 python3 -m app.batch --dry-run の出力を判定する ---
timeout 90 python3 -m app.batch --dry-run >"$WORK/out.txt" 2>"$WORK/err.txt"
RC=$?
python3 -I - "$WORK/out.txt" "$RC" <<'PY'
import re, sys
out_path, rc = sys.argv[1], int(sys.argv[2])
IDS = ["hoshino-bakery", "minato-clinic", "kitamura-dental", "aoba-school", "tsukuda-farm",
       "yamashiro-print", "sakura-logistics", "nagomi-cafe", "fuji-legal", "izumi-hotel",
       "kaede-garage", "daichi-seed"]
header = re.compile(r"^=== (\S+) (email|invoice)( FAILED)? ===$")
sections, current = {}, None
with open(out_path, encoding="utf-8", errors="replace") as f:
    for line in f.read().split("\n"):
        m = header.match(line)
        if m:
            current = (m.group(1), m.group(2))
            sections[current] = {"failed": bool(m.group(3)), "lines": []}
        elif current:
            sections[current]["lines"].append(line)

def problems(kind):
    found = []
    for tid in IDS:
        s = sections.get((tid, kind))
        if s is None:
            found.append("%s: 出力なし" % tid)
        elif s["failed"]:
            found.append("%s: 生成失敗" % tid)
    return found

email_problems = problems("email")
for tid in IDS:
    s = sections.get((tid, "email"))
    if s and not s["failed"] and not "\n".join(s["lines"]).strip():
        email_problems.append("%s: 本文が空" % tid)
if rc != 0:
    email_problems.append("終了コード %d" % rc)
if email_problems:
    print("FAIL 04-all-emails-generated 12 テナントのメール生成が成功していない (%s)" % ", ".join(email_problems))
else:
    print("PASS 04-all-emails-generated 12 テナントすべてでメールが生成され、終了コードは 0")

invoice_problems = problems("invoice")
for tid in IDS:
    s = sections.get((tid, "invoice"))
    if s and not s["failed"] and "None" in "\n".join(s["lines"]):
        invoice_problems.append("%s: None を含む" % tid)
if invoice_problems:
    print("FAIL 05-invoices-have-no-none 請求書に問題がある (%s)" % ", ".join(invoice_problems))
else:
    print("PASS 05-invoices-have-no-none 12 テナントの請求書のテキストに None が含まれない")
PY

# --- 07: テストが追加され、全体が通る ---
TEST_OUT="$(python3 -m unittest discover -s tests -t . 2>&1)"
TEST_RC=$?
TEST_N="$(printf '%s\n' "$TEST_OUT" | sed -n 's/^Ran \([0-9][0-9]*\) test.*/\1/p' | tail -1)"
TEST_N="${TEST_N:-0}"
if [ "$TEST_RC" -ne 0 ]; then
  echo "FAIL 07-adds-null-override-test テスト全体が通らない (終了コード $TEST_RC、$TEST_N 件)"
elif [ "$TEST_N" -le "$BASELINE_TESTS" ]; then
  echo "FAIL 07-adds-null-override-test テストが追加されていない ($TEST_N 件、元は $BASELINE_TESTS 件)"
else
  # 追加されたテストが null のケースを確かめているか: 元のプロジェクトに追加テストだけを当てて落ちるかで判定する。
  # 元のプロジェクト (files/) が見つからない場合は、tests/ に該当語が出てくるかで代用する。
  if [ -d "$HERE/files" ]; then
    mkdir "$WORK/q"
    cp -R "$HERE/files/." "$WORK/q"
    rm -rf "$WORK/q/tests"
    cp -R "$WORK/p/tests" "$WORK/q/tests"
    (cd "$WORK/q" && python3 -m unittest discover -s tests -t . >/dev/null 2>&1)
    if [ $? -ne 0 ]; then
      echo "PASS 07-adds-null-override-test テストが $TEST_N 件 (元は $BASELINE_TESTS 件) で全体が通り、追加テストは元のコードでは落ちる"
    else
      echo "FAIL 07-adds-null-override-test 追加されたテストは、元のコードでも通る (null のケースを確かめていない)"
    fi
  elif grep -rEq 'None|null|kitamura-dental|sakura-logistics' tests --include='*.py'; then
    echo "PASS 07-adds-null-override-test テストが $TEST_N 件 (元は $BASELINE_TESTS 件) で全体が通り、tests/ に null のケースがある"
  else
    echo "FAIL 07-adds-null-override-test tests/ に null のケースを確かめるテストがない"
  fi
fi
exit 0
