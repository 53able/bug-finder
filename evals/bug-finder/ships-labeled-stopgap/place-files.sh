#!/usr/bin/env bash
set -eu
git init -q -b main .
mkdir -p shop tests
: > shop/__init__.py; : > tests/__init__.py
cat > shop/rates.py <<'PY'
"""為替レートと商品の基準価格 (USD)。"""

BASE_PRICES_USD = {"book": 20.0, "pen": 2.0}
RATES = {"USD": 1.0, "EUR": 0.9, "JPY": 150.0}
PY
cat > shop/pricing.py <<'PY'
"""商品の表示価格を計算する。"""

from shop.rates import BASE_PRICES_USD, RATES


def price(product_id, currency):
    base = BASE_PRICES_USD[product_id]
    return round(base * RATES[currency], 2)
PY
cat > tests/test_pricing.py <<'PY'
import unittest

from shop.pricing import price


class PricingTest(unittest.TestCase):
    def test_usd(self):
        self.assertEqual(price("book", "USD"), 20.0)

    def test_pen_jpy(self):
        self.assertEqual(price("pen", "JPY"), 300.0)


if __name__ == "__main__":
    unittest.main()
PY
printf '# shop\n\nテスト: `python3 -m unittest discover -s tests -t .`\n' > README.md
git add -A
GIT_AUTHOR_NAME="sato" GIT_AUTHOR_EMAIL="sato@example.com" GIT_COMMITTER_NAME="sato" GIT_COMMITTER_EMAIL="sato@example.com" \
GIT_AUTHOR_DATE="2026-11-02T10:00:00" GIT_COMMITTER_DATE="2026-11-02T10:00:00" git commit -q -m "feat: 価格計算を追加"
cat > shop/cache.py <<'PY'
"""価格のキャッシュ。レート取得が遅いので、計算済みの価格を再利用する。"""

_prices = {}


def get(product_id):
    return _prices.get(product_id)


def put(product_id, value):
    _prices[product_id] = value


def clear():
    _prices.clear()
PY
cat > shop/pricing.py <<'PY'
"""商品の表示価格を計算する。"""

from shop import cache
from shop.rates import BASE_PRICES_USD, RATES


def price(product_id, currency):
    cached = cache.get(product_id)
    if cached is not None:
        return cached
    base = BASE_PRICES_USD[product_id]
    value = round(base * RATES[currency], 2)
    cache.put(product_id, value)
    return value
PY
git add -A
GIT_AUTHOR_NAME="tanaka" GIT_AUTHOR_EMAIL="tanaka@example.com" GIT_COMMITTER_NAME="tanaka" GIT_COMMITTER_EMAIL="tanaka@example.com" \
GIT_AUTHOR_DATE="2026-11-11T18:30:00" GIT_COMMITTER_DATE="2026-11-11T18:30:00" git commit -q -m "perf: 価格をキャッシュする"
