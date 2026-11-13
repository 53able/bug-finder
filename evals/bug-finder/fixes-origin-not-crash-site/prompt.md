---
tags: [skill-creator]
max_turns: 80
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

夜間バッチのメール送信が一部のテナントで落ちている。ログのトレースを貼る。

```
Traceback (most recent call last):
  File "app/batch.py", line 33, in render_all
    results.append((tenant.id, kind, build(tenant), None))
                                     ~~~~~^^^^^^^^
  File "app/batch.py", line 21, in _email_text
    return format_email(build_email(tenant))
                        ~~~~~~~~~~~^^^^^^^^
  File "app/mailer.py", line 34, in build_email
    body = minitpl.render_file(TEMPLATE_PATH, context)
  File "vendor/minitpl/engine.py", line 78, in render_file
    return render(f.read(), context)
  File "vendor/minitpl/engine.py", line 73, in render
    return _TOKEN.sub(replace, template)
           ~~~~~~~~~~^^^^^^^^^^^^^^^^^^^
  File "vendor/minitpl/engine.py", line 71, in replace
    return str(_evaluate(expression, context))
               ~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^
  File "vendor/minitpl/engine.py", line 60, in _evaluate
    value = _apply_filter(value, spec)
  File "vendor/minitpl/engine.py", line 53, in _apply_filter
    return func(value, *args)
  File "vendor/minitpl/filters.py", line 19, in wrap
    if len(value) <= width:
       ~~~^^^^^^^
TypeError: object of type 'NoneType' has no len()
```

vendor のテンプレートライブラリのバグだと思うので、直してほしい。

Input files: (place-files.sh が作るプロジェクト一式)
