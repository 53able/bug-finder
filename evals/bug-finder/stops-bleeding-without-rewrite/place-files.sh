#!/usr/bin/env bash
# 履歴付きの git リポジトリをカレントディレクトリに作る。
# files/NN/ が NN 番目のコミットで置く (追加・上書きする) ファイル。
set -eu
export PYTHONDONTWRITEBYTECODE=1
here="$(cd "$(dirname "$0")" && pwd)"
n=0
commit() {
  # commit <作者> <メール> <日時> <件名> [本文]
  n=$((n+1))
  cp -R "$here/files/$(printf '%02d' "$n")/." .
  git add -A
  GIT_AUTHOR_NAME="$1" GIT_AUTHOR_EMAIL="$2" GIT_COMMITTER_NAME="$1" GIT_COMMITTER_EMAIL="$2" \
    GIT_AUTHOR_DATE="$3" GIT_COMMITTER_DATE="$3" \
    git commit -q -m "$4" ${5:+-m "$5"}
}
git init -q -b main .

S="Haruka Suzuki"; SE="suzuki@example.com"
O="Daichi Ono"; OE="ono@example.com"
M="Kenta Mori"; ME="mori@example.com"
I="Aya Ito"; IE="ito@example.com"

commit "$S" "$SE" "2026-10-01T10:00:00+09:00" "feat: 在庫と注文の基本モデルを追加"
commit "$S" "$SE" "2026-10-03T11:20:00+09:00" "feat: 倉庫への出庫指示を追加"
commit "$O" "$OE" "2026-10-06T15:05:00+09:00" "feat: 注文の引当を追加"
commit "$O" "$OE" "2026-10-08T14:30:00+09:00" "feat: 注文の受付サービスを追加"
commit "$S" "$SE" "2026-10-10T16:45:00+09:00" "feat: 見積もりを追加"
commit "$M" "$ME" "2026-10-15T13:10:00+09:00" "chore: 注文の流れを再現するスクリプトを追加" "本番で観測した倉庫 API の応答時間に合わせてある。"
commit "$S" "$SE" "2026-10-17T10:30:00+09:00" "docs: README を追加"
commit "$O" "$OE" "2026-10-22T17:00:00+09:00" "feat: 在庫のスナップショットを追加"
commit "$M" "$ME" "2026-10-27T11:40:00+09:00" "fix: 倉庫のエラーを数回まで試し直す"
commit "$S" "$SE" "2026-10-30T15:20:00+09:00" "feat: 見積もりを税込にする"
commit "$O" "$OE" "2026-11-05T10:10:00+09:00" "docs: README に開発手順を追記"
commit "$O" "$OE" "2026-11-09T14:00:00+09:00" "test: 注文のテストを追加"
commit "$M" "$ME" "2026-11-12T17:40:00+09:00" "feat: 注文の引当をジョブキュー経由にする" \
"倉庫 API の応答待ちで受付が詰まるのを避けるため、引当をキューに積んでワーカーで処理する。
- stock/jobqueue.py: lease つきのジョブキュー
- stock/worker.py: 引当ジョブのワーカー
- stock/dispatcher.py: ワーカーへの振り分け
- stock/retry.py: 倉庫エラー時の再試行 (指数バックオフ)
同期の allocate_order はしばらく残す。"
commit "$I" "$IE" "2026-11-13T09:12:00+09:00" "feat: 注文の受付時に明細を検証する"
commit "$S" "$SE" "2026-11-13T10:05:00+09:00" "feat: 見積もりに割引コードを追加"

find . -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true
