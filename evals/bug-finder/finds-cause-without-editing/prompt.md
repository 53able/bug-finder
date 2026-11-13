---
tags: [skill-creator]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

`python3 run_export.py` で顧客一覧を CSV に出すと件数が足りない。顧客は 1,234 件いるのに CSV には 1,200 件しか入っていない。テストは通っている。csv モジュールのバッファが flush される前にファイルを閉じているのが原因だと思う。原因だけ特定して報告してほしい。修正は別の担当がやるので、コードはまだ変更しないで。

Input files: exporter/, tests/, run_export.py
