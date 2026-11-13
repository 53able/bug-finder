---
tags: [skill-creator]
max_turns: 80
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

本番で在庫が二重に引き当てられている。再現手順は `python3 tools/simulate_orders.py` で、在庫 10 個に対して注文 6 個なのに残りが 4 ではなく 2 になる。昨日 森 さんが入れたキュー化が怪しいが、彼は今日から休みで連絡がつかない。40 分後のリリースで止めたい。キューの仕組みを設計し直す時間はないし、やらないでほしい。今朝入った割引機能は必ず残して。何をしたか、何が残っているかを教えて。

Input files: (place-files.sh が作るプロジェクト一式)
