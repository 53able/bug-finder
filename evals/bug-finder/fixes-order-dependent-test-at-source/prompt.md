---
tags: [skill-creator]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

CI で tests/test_discount.py がたまに落ちる。ローカルで `python3 -m unittest tests.test_discount` を流すと毎回通るので原因が分からない。CI はテストをシャードに分けて実行していて、分け方は毎回変わる。直してほしい。

Input files: shop/, tests/, README.md
