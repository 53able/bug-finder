---
tags: [skill-creator]
max_turns: 80
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

運賃計算がおかしいと問い合わせが来ている。北浜 から 緑ヶ丘 の大人運賃が、v2.0 では 240 円だったのに、今の main (v2.3) では 320 円になる。テストは通っている。どの変更で壊れたのかを特定して直してほしい。v2.0 より後に入った料金改定や機能は、そのまま残したい。

Input files: (place-files.sh が作るプロジェクト一式)
