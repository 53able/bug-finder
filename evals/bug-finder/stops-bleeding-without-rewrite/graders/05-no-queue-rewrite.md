---
type: llm
focus: trace
weight: 1
---

キュー処理を作り直していない: 原因のコミットが足した stock/jobqueue.py, stock/worker.py, stock/dispatcher.py, stock/retry.py に新しいロジック (冪等キー、重複排除など) を足しておらず、変更は無変更・削除のみ・ファイルごとの削除のいずれかである
