#!/usr/bin/env bash
# 履歴付きの git リポジトリをカレントディレクトリに作る
set -eu
export GIT_AUTHOR_NAME="dev" GIT_AUTHOR_EMAIL="dev@example.com" GIT_COMMITTER_NAME="dev" GIT_COMMITTER_EMAIL="dev@example.com"
n=0
commit() { n=$((n+1)); d="2026-09-$(printf '%02d' $n)T10:00:00"; git add -A; GIT_AUTHOR_DATE="$d" GIT_COMMITTER_DATE="$d" git commit -q -m "$1"; }
git init -q -b main .
mkdir -p textkit tests
: > textkit/__init__.py; : > tests/__init__.py

cat > textkit/slug.py <<'PY'
"""記事タイトルから URL 用の文字列を作る。"""

import re


def slugify(title):
    text = title.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-")
PY
cat > tests/test_slug.py <<'PY'
import unittest

from textkit.slug import slugify


class SlugTest(unittest.TestCase):
    def test_basic(self):
        self.assertEqual(slugify("Hello World"), "hello-world")


if __name__ == "__main__":
    unittest.main()
PY
printf '# textkit\n\nテスト: `python3 -m unittest discover -s tests -t .`\n' > README.md
commit "feat: slugify を追加"

cat > textkit/wordcount.py <<'PY'
"""単語数を数える。"""


def word_count(text):
    return len(text.split())
PY
commit "feat: word_count を追加"

printf '\n## 機能\n\n- slugify\n- word_count\n' >> README.md
commit "docs: README に機能一覧を追加"
git tag v1.0

cat > tests/test_wordcount.py <<'PY'
import unittest

from textkit.wordcount import word_count


class WordCountTest(unittest.TestCase):
    def test_counts_words(self):
        self.assertEqual(word_count("a b  c"), 3)


if __name__ == "__main__":
    unittest.main()
PY
commit "test: word_count のテストを追加"

cat > textkit/slug.py <<'PY'
"""記事タイトルから URL 用の文字列を作る。"""

import re
import unicodedata


def _to_ascii(text):
    normalized = unicodedata.normalize("NFKD", text)
    return normalized.encode("ascii", "ignore").decode("ascii")


def slugify(title):
    text = _to_ascii(title).lower()
    text = re.sub(r"\s+", "-", text)
    text = re.sub(r"[^a-z0-9-]", "", text)
    return text.strip("-")
PY
python3 - <<'PY'
p = "tests/test_slug.py"; s = open(p).read()
s = s.replace('''        self.assertEqual(slugify("Hello World"), "hello-world")
''', '''        self.assertEqual(slugify("Hello World"), "hello-world")

    def test_accents(self):
        self.assertEqual(slugify("Crème Brûlée"), "creme-brulee")
''')
open(p, "w").write(s)
PY
commit "feat: アクセント付き文字を ASCII に変換する"

cat > textkit/wordcount.py <<'PY'
"""単語数を数える。"""


def word_count(text):
    return len(text.split())


def char_count(text, include_spaces=True):
    if include_spaces:
        return len(text)
    return len("".join(text.split()))
PY
commit "feat: char_count を追加"
git tag v1.1

printf -- '- char_count\n' >> README.md
commit "docs: README を更新"

python3 - <<'PY'
p = "textkit/slug.py"; s = open(p).read()
s = s.replace('''def slugify(title):
    text = _to_ascii(title).lower()
    text = re.sub(r"\\s+", "-", text)
    text = re.sub(r"[^a-z0-9-]", "", text)
    return text.strip("-")
''', '''def slugify(title, max_length=None):
    text = _to_ascii(title).lower()
    text = re.sub(r"\\s+", "-", text)
    text = re.sub(r"[^a-z0-9-]", "", text)
    text = text.strip("-")
    if max_length is not None:
        text = text[:max_length].rstrip("-")
    return text
''')
open(p, "w").write(s)
p = "tests/test_slug.py"; s = open(p).read()
s = s.replace('''

if __name__''', '''
    def test_max_length(self):
        self.assertEqual(slugify("Hello World Again", max_length=11), "hello-world")


if __name__''', 1)
open(p, "w").write(s)
PY
commit "feat: slugify に max_length を追加"

cat > textkit/reading.py <<'PY'
"""読了時間の目安。"""

from textkit.wordcount import word_count


def reading_minutes(text, words_per_minute=200):
    return max(1, round(word_count(text) / words_per_minute))
PY
commit "feat: reading_minutes を追加"

printf -- '- reading_minutes\n' >> README.md
commit "docs: README に reading_minutes を追記"
git tag v1.2
