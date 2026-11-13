---
type: llm
focus: trace
weight: 1
---

報告は、app/_generated/http.py に schema/http.json に無い手入れ (base_url の末尾スラッシュを落とす処理) があったことと、それを schema 側 (normalize: strip_trailing_slash) へ移してから生成し直したことに触れている
