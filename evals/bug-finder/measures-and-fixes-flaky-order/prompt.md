---
tags: [skill-creator]
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

tests/test_tags.py がときどき落ちる。再実行すると通ることも多いので、CI ではリトライでごまかしている。コードは何週間も変えていない。原因を突き止めて直してほしい。直ったことが分かる根拠も欲しい。

Input files: blog/, tests/, README.md
