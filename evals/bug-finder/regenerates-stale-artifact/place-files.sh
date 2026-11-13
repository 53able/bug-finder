#!/usr/bin/env bash
# 履歴付きの git リポジトリをカレントディレクトリに作る
set -eu
export PYTHONDONTWRITEBYTECODE=1
export GIT_AUTHOR_NAME="dev" GIT_AUTHOR_EMAIL="dev@example.com" GIT_COMMITTER_NAME="dev" GIT_COMMITTER_EMAIL="dev@example.com"
n=0
commit() { n=$((n+1)); d="2026-10-$(printf '%02d' $((n*3)))T10:00:00"; git add -A; GIT_AUTHOR_DATE="$d" GIT_COMMITTER_DATE="$d" git commit -q -m "$1"; }
git init -q -b main .
mkdir -p app/_generated schema tests tools
printf '__pycache__/\n' > .gitignore

# ---- 1: スキーマ、生成スクリプト、http セクション ----
cat > schema/http.json <<'JSON'
{
  "section": "http",
  "fields": {
    "timeout_seconds": {"type": "int", "default": 10, "min": 1, "max": 120},
    "max_redirects": {"type": "int", "default": 3, "min": 0, "max": 10},
    "user_agent": {"type": "str", "default": "appclient/1.0"},
    "base_url": {"type": "str", "default": "http://localhost:8080"}
  }
}
JSON

cat > tools/generate.py <<'PY'
"""設定スキーマ (schema/*.json) から app/_generated/*.py を生成する。

使い方: python3 tools/generate.py
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCHEMA_DIR = ROOT / "schema"
OUT_DIR = ROOT / "app" / "_generated"

NORMALIZERS = {
    "strip": ".strip()",
    "lower": ".lower()",
    "strip_trailing_slash": '.rstrip("/")',
}

BUILD = '''def build(overrides=None):
    """既定値に上書きを重ねた設定を返す。"""
    overrides = overrides or {}
    for key in overrides:
        if key not in _COERCE:
            raise KeyError("%s に未知の項目: %s" % (SECTION, key))
    values = dict(DEFAULTS)
    values.update(overrides)
    return {key: _COERCE[key](value) for key, value in values.items()}'''


def _check(cond, message):
    return [f"    if {cond}:", f"        raise ValueError({message!r} % (value,))"]


def _render_coerce(name, spec):
    kind = spec["type"]
    lines = [f"def _coerce_{name}(value):"]
    if kind == "int":
        lines.append("    value = int(value)")
        if "min" in spec:
            lines += _check(f"value < {spec['min']!r}", f"{name} は {spec['min']} 以上: %r")
        if "max" in spec:
            lines += _check(f"value > {spec['max']!r}", f"{name} は {spec['max']} 以下: %r")
        lines.append("    return value")
    elif kind == "str":
        expr = "str(value)"
        if "normalize" in spec:
            expr += NORMALIZERS[spec["normalize"]]
        if "choices" in spec:
            lines.append(f"    value = {expr}")
            lines += _check(
                f"value not in {tuple(spec['choices'])!r}",
                f"{name} は {'/'.join(spec['choices'])} のいずれか: %r",
            )
            lines.append("    return value")
        else:
            lines.append(f"    return {expr}")
    elif kind == "bool":
        lines.append("    return bool(value)")
    else:
        raise ValueError(f"未対応の型: {kind}")
    return "\n".join(lines)


def render(schema):
    section = schema["section"]
    fields = schema["fields"]
    head = [
        f"# 自動生成。編集しない。生成元: schema/{section}.json (tools/generate.py)",
        f'"""{section} セクションの設定。"""',
        "",
        f'SECTION = "{section}"',
        "",
        "DEFAULTS = {",
    ]
    head += [f"    {name!r}: {spec['default']!r}," for name, spec in fields.items()]
    head.append("}")
    table = ["_COERCE = {"]
    table += [f"    {name!r}: _coerce_{name}," for name in fields]
    table.append("}")
    blocks = ["\n".join(head)]
    blocks += [_render_coerce(name, spec) for name, spec in fields.items()]
    blocks += ["\n".join(table), BUILD]
    return "\n\n\n".join(blocks) + "\n"


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for path in sorted(SCHEMA_DIR.glob("*.json")):
        schema = json.loads(path.read_text(encoding="utf-8"))
        out = OUT_DIR / (schema["section"] + ".py")
        out.write_text(render(schema), encoding="utf-8")
        print("生成:", out.relative_to(ROOT))


if __name__ == "__main__":
    main()
PY

cat > app/__init__.py <<'PY'
"""設定スキーマから生成した設定で動く小さなアプリ。"""
PY
: > app/_generated/__init__.py
: > tests/__init__.py
python3 tools/generate.py > /dev/null

cat > tests/test_generate.py <<'PY'
import unittest

from tools import generate

SCHEMA = {
    "section": "demo",
    "fields": {
        "count": {"type": "int", "default": 2, "min": 1, "max": 5},
        "name": {"type": "str", "default": "x", "normalize": "lower"},
        "mode": {"type": "str", "default": "a", "choices": ["a", "b"]},
        "flag": {"type": "bool", "default": False},
    },
}


def load_module():
    namespace = {}
    exec(compile(generate.render(SCHEMA), "<demo>", "exec"), namespace)
    return namespace


class GenerateTest(unittest.TestCase):
    def test_defaults(self):
        built = load_module()["build"]()
        self.assertEqual(built, {"count": 2, "name": "x", "mode": "a", "flag": False})

    def test_override_is_coerced(self):
        built = load_module()["build"]({"count": "4", "name": "ABC", "flag": 1})
        self.assertEqual(built["count"], 4)
        self.assertEqual(built["name"], "abc")
        self.assertIs(built["flag"], True)

    def test_range_is_checked(self):
        with self.assertRaises(ValueError):
            load_module()["build"]({"count": 6})

    def test_choices_are_checked(self):
        with self.assertRaises(ValueError):
            load_module()["build"]({"mode": "c"})

    def test_unknown_key(self):
        with self.assertRaises(KeyError):
            load_module()["build"]({"nope": 1})


if __name__ == "__main__":
    unittest.main()
PY
printf '# appconf\n\n設定を schema/ に宣言し、実行時はそこから作った設定モジュールを使う。\n\nテスト: `python3 -m unittest discover -s tests -t .`\n' > README.md
commit "feat: 設定スキーマと生成スクリプトを追加"

# ---- 2: HTTP クライアント ----
cat > app/config.py <<'PY'
"""設定の読み込み。生成された各セクションの build() を束ねる。"""

import json

from app._generated import http

SECTIONS = {
    "http": http,
}


def load(overrides=None):
    """全セクションの設定を {セクション: {項目: 値}} で返す。"""
    overrides = overrides or {}
    for name in overrides:
        if name not in SECTIONS:
            raise KeyError("未知のセクション: %s" % name)
    return {name: module.build(overrides.get(name)) for name, module in SECTIONS.items()}


def load_file(path):
    """JSON ファイルの上書き設定を読んで load() に渡す。"""
    with open(path, encoding="utf-8") as f:
        return load(json.load(f))
PY

cat > app/client.py <<'PY'
"""HTTP リクエストの組み立てと送信。送信そのものは呼び出し側が渡す transport が行う。"""

from urllib.parse import urlencode

from app import config


class HttpClient:
    def __init__(self, overrides=None):
        self.settings = config.load({"http": overrides})["http"]

    @property
    def timeout(self):
        return self.settings["timeout_seconds"]

    def build_url(self, path, params=None):
        url = self.settings["base_url"] + "/" + path.lstrip("/")
        if params:
            url += "?" + urlencode(sorted(params.items()))
        return url

    def headers(self):
        return {"User-Agent": self.settings["user_agent"], "Accept": "application/json"}

    def request(self, path, params=None):
        return {
            "method": "GET",
            "url": self.build_url(path, params),
            "headers": self.headers(),
            "timeout": self.timeout,
            "max_redirects": self.settings["max_redirects"],
        }

    def send(self, path, transport, params=None):
        """transport(request) の応答を返す。リダイレクトが上限を超えていたら例外にする。"""
        request = self.request(path, params)
        response = transport(request)
        if response.get("redirects", 0) > request["max_redirects"]:
            raise RuntimeError("リダイレクトが多すぎる: %s" % request["url"])
        return response
PY

cat > tests/test_client.py <<'PY'
import unittest

from app.client import HttpClient


class HttpClientTest(unittest.TestCase):
    def test_build_url(self):
        client = HttpClient()
        self.assertEqual(client.build_url("/items"), "http://localhost:8080/items")
        self.assertEqual(client.build_url("items"), "http://localhost:8080/items")

    def test_query_is_sorted(self):
        url = HttpClient().build_url("/items", {"b": 2, "a": 1})
        self.assertTrue(url.endswith("/items?a=1&b=2"))

    def test_headers(self):
        headers = HttpClient({"user_agent": "probe/2"}).headers()
        self.assertEqual(headers["User-Agent"], "probe/2")
        self.assertEqual(headers["Accept"], "application/json")

    def test_timeout_override(self):
        self.assertEqual(HttpClient({"timeout_seconds": 5}).timeout, 5)

    def test_timeout_out_of_range(self):
        with self.assertRaises(ValueError):
            HttpClient({"timeout_seconds": 0})

    def test_send_returns_response(self):
        client = HttpClient()
        seen = []

        def transport(request):
            seen.append(request)
            return {"status": 200}

        self.assertEqual(client.send("/ping", transport), {"status": 200})
        self.assertEqual(seen[0]["url"], "http://localhost:8080/ping")

    def test_send_rejects_too_many_redirects(self):
        client = HttpClient({"max_redirects": 1})
        with self.assertRaises(RuntimeError):
            client.send("/ping", lambda request: {"status": 302, "redirects": 2})


if __name__ == "__main__":
    unittest.main()
PY
commit "feat: HTTP クライアントを追加"

# ---- 3: mail セクション ----
cat > schema/mail.json <<'JSON'
{
  "section": "mail",
  "fields": {
    "sender": {"type": "str", "default": "noreply@example.com", "normalize": "lower"},
    "subject_prefix": {"type": "str", "default": "[app] "},
    "max_recipients": {"type": "int", "default": 20, "min": 1, "max": 100},
    "use_tls": {"type": "bool", "default": true}
  }
}
JSON
python3 tools/generate.py > /dev/null

cat > app/mailer.py <<'PY'
"""メッセージの組み立て。"""

from app import config


class Mailer:
    def __init__(self, overrides=None):
        self.settings = config.load({"mail": overrides})["mail"]

    def compose(self, recipients, subject, body):
        if not recipients:
            raise ValueError("宛先がない")
        if len(recipients) > self.settings["max_recipients"]:
            raise ValueError("宛先が多すぎる: %d" % len(recipients))
        return {
            "from": self.settings["sender"],
            "to": list(recipients),
            "subject": self.settings["subject_prefix"] + subject,
            "body": body,
            "tls": self.settings["use_tls"],
        }

    def split_batches(self, recipients):
        """宛先を max_recipients ごとのかたまりに分ける。"""
        size = self.settings["max_recipients"]
        return [list(recipients[i:i + size]) for i in range(0, len(recipients), size)]
PY

cat > tests/test_mailer.py <<'PY'
import unittest

from app.mailer import Mailer


class MailerTest(unittest.TestCase):
    def test_compose(self):
        message = Mailer().compose(["a@example.com"], "確認", "本文")
        self.assertEqual(message["from"], "noreply@example.com")
        self.assertEqual(message["subject"], "[app] 確認")
        self.assertTrue(message["tls"])

    def test_sender_is_lowercased(self):
        message = Mailer({"sender": "NoReply@Example.COM"}).compose(["a@example.com"], "s", "b")
        self.assertEqual(message["from"], "noreply@example.com")

    def test_no_recipients(self):
        with self.assertRaises(ValueError):
            Mailer().compose([], "s", "b")

    def test_too_many_recipients(self):
        with self.assertRaises(ValueError):
            Mailer({"max_recipients": 2}).compose(["a", "b", "c"], "s", "b")

    def test_split_batches(self):
        batches = Mailer({"max_recipients": 2}).split_batches(["a", "b", "c", "d", "e"])
        self.assertEqual(batches, [["a", "b"], ["c", "d"], ["e"]])


if __name__ == "__main__":
    unittest.main()
PY
python3 - <<'PY'
p = "app/config.py"; s = open(p).read()
s = s.replace("import http\n", "import http, mail\n")
s = s.replace('    "http": http,\n', '    "http": http,\n    "mail": mail,\n')
open(p, "w").write(s)
PY
commit "feat: mail セクションとメッセージ組み立てを追加"

# ---- 4: ui セクション、エントリポイント ----
cat > schema/ui.json <<'JSON'
{
  "section": "ui",
  "fields": {
    "page_size": {"type": "int", "default": 25, "min": 1, "max": 200},
    "theme": {"type": "str", "default": "light", "choices": ["light", "dark"]},
    "date_format": {"type": "str", "default": "%Y-%m-%d"}
  }
}
JSON
python3 tools/generate.py > /dev/null

cat > app/pager.py <<'PY'
"""一覧の分割表示。"""

from app import config


class Pager:
    def __init__(self, overrides=None):
        self.settings = config.load({"ui": overrides})["ui"]

    def page_count(self, total):
        size = self.settings["page_size"]
        return max(1, (total + size - 1) // size)

    def page(self, items, number):
        """number は 1 始まり。範囲外は IndexError。"""
        if number < 1 or number > self.page_count(len(items)):
            raise IndexError("ページ番号が範囲外: %d" % number)
        size = self.settings["page_size"]
        return items[(number - 1) * size:number * size]

    def label(self, when):
        return when.strftime(self.settings["date_format"])
PY

cat > app/__main__.py <<'PY'
"""使い方: python3 -m app [セクション.項目]  (有効な設定を表示する)"""

import json
import sys

from app import config


def main(argv):
    settings = config.load()
    if len(argv) == 1:
        print(json.dumps(settings, ensure_ascii=False, indent=2, sort_keys=True))
        return 0
    section, _, key = argv[1].partition(".")
    try:
        print(settings[section][key])
    except KeyError:
        print("未知の項目: " + argv[1], file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
PY

cat > tests/test_pager.py <<'PY'
import datetime
import unittest

from app.pager import Pager


class PagerTest(unittest.TestCase):
    def test_page_count(self):
        pager = Pager({"page_size": 10})
        self.assertEqual(pager.page_count(0), 1)
        self.assertEqual(pager.page_count(10), 1)
        self.assertEqual(pager.page_count(11), 2)

    def test_page_slices(self):
        pager = Pager({"page_size": 3})
        items = list(range(7))
        self.assertEqual(pager.page(items, 1), [0, 1, 2])
        self.assertEqual(pager.page(items, 3), [6])

    def test_page_out_of_range(self):
        with self.assertRaises(IndexError):
            Pager({"page_size": 3}).page([1, 2], 2)

    def test_theme_must_be_known(self):
        with self.assertRaises(ValueError):
            Pager({"theme": "sepia"})

    def test_label(self):
        self.assertEqual(Pager().label(datetime.date(2026, 10, 1)), "2026-10-01")


if __name__ == "__main__":
    unittest.main()
PY
python3 - <<'PY'
p = "app/config.py"; s = open(p).read()
s = s.replace("import http, mail\n", "import http, mail, ui\n")
s = s.replace('    "mail": mail,\n', '    "mail": mail,\n    "ui": ui,\n')
open(p, "w").write(s)
PY
commit "feat: ui セクションとページ分割を追加"

# ---- 5: base_url の末尾スラッシュ ----
python3 - <<'PY'
p = "app/_generated/http.py"; s = open(p).read()
old = 'def _coerce_base_url(value):\n    return str(value)\n'
assert old in s
s = s.replace(old, 'def _coerce_base_url(value):\n    return str(value).rstrip("/")\n')
open(p, "w").write(s)
PY
commit "fix: base_url 末尾のスラッシュで URL が二重になる問題を直す"

# ---- 6: 設定のテスト ----
cat > tests/test_config.py <<'PY'
import json
import os
import tempfile
import unittest

from app import config


class ConfigTest(unittest.TestCase):
    def test_defaults(self):
        settings = config.load()
        self.assertEqual(settings["http"]["timeout_seconds"], 10)
        self.assertEqual(settings["http"]["max_redirects"], 3)
        self.assertEqual(settings["mail"]["max_recipients"], 20)
        self.assertEqual(settings["ui"]["page_size"], 25)

    def test_override_one_section(self):
        settings = config.load({"ui": {"page_size": 50}})
        self.assertEqual(settings["ui"]["page_size"], 50)
        self.assertEqual(settings["ui"]["theme"], "light")

    def test_unknown_section(self):
        with self.assertRaises(KeyError):
            config.load({"nope": {}})

    def test_unknown_key(self):
        with self.assertRaises(KeyError):
            config.load({"http": {"nope": 1}})

    def test_load_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "override.json")
            with open(path, "w", encoding="utf-8") as f:
                json.dump({"mail": {"use_tls": False}}, f)
            settings = config.load_file(path)
        self.assertFalse(settings["mail"]["use_tls"])


if __name__ == "__main__":
    unittest.main()
PY
commit "test: 設定の読み込みのテストを追加"

# ---- 7: README ----
printf '\n## 設定\n\n- 項目の宣言: `schema/*.json`\n- 設定モジュールの生成: `python3 tools/generate.py` (出力先は `app/_generated/`)\n- 確認: `python3 -m app` で有効な設定を表示する\n' >> README.md
commit "docs: README に設定の作り方を追記"

# ---- 8: 既定値の変更 (schema のみ) ----
python3 - <<'PY'
p = "schema/http.json"; s = open(p).read()
old = '"timeout_seconds": {"type": "int", "default": 10,'
assert old in s
open(p, "w").write(s.replace(old, '"timeout_seconds": {"type": "int", "default": 30,'))
PY
commit "fix: http.timeout_seconds の既定値を 30 秒にする"

find . -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true
