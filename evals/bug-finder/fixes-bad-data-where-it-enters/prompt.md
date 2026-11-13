---
tags: [skill-creator]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

`python3 report.py` の売上ランキングがおかしい。上位3件に 1,200 円の取引 (T002) が入っておらず、代わりに 87 円の取引が入っている。合計は合っている。直してほしい。

Input files: sales/, data/, tests/, report.py
