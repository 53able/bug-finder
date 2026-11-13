---
tags: [skill-creator]
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

記事の URL が変わってリンク切れが起きている。タイトル「Rock & Roll -- Live」の slug は v1.0 では `rock-roll-live` だったのに、今は `rock--roll----live` になる。テストは全部通っている。どのコミットで壊れたのかを特定して、直してほしい。v1.0 より後に入った機能は残したい。

Input files: (git リポジトリ一式)
