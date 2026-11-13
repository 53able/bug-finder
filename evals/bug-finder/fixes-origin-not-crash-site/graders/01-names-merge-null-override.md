---
type: llm
focus: trace
weight: 1
---

報告は、原因が同梱ライブラリ (vendor/minitpl) ではなく、app/config.py の merge_settings が、テナントの上書き設定にある null (None) で既定値を上書きしていることだと特定している
