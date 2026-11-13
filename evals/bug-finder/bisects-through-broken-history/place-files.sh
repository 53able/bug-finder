#!/usr/bin/env bash
# 運賃計算ライブラリの git 履歴 (約 60 コミット、タグ v2.0 と v2.3) をカレントディレクトリに作る
set -eu
export PYTHONDONTWRITEBYTECODE=1
export GIT_AUTHOR_NAME="dev" GIT_AUTHOR_EMAIL="dev@example.com" GIT_COMMITTER_NAME="dev" GIT_COMMITTER_EMAIL="dev@example.com"
n=0
commit() {
  n=$((n+1))
  d="2026-$(printf '%02d' $((3 + (n-1)/20)))-$(printf '%02d' $((1 + (n-1)%20)))T10:00:00+09:00"
  git add -A
  GIT_AUTHOR_DATE="$d" GIT_COMMITTER_DATE="$d" git -c commit.gpgsign=false commit -q --no-verify -m "$1"
}
# sub FILE: 標準入力の「旧\n=====\n新」で、FILE の旧 (1 か所だけ) を新に置き換える
sub() {
  python3 -c '
import re, sys
path = sys.argv[1]
data = sys.stdin.read()
if data.endswith("\n"):
    data = data[:-1]
old, new = re.split(r"\n=====(?:\n|$)", data, maxsplit=1)
text = open(path, encoding="utf-8").read()
if text.count(old) != 1:
    sys.exit("sub: %s で置換対象が %d 件" % (path, text.count(old)))
open(path, "w", encoding="utf-8").write(text.replace(old, new))
' "$1"
}
git init -q -b main .
mkdir -p fares data tests

# ---- 1 ----
printf '__pycache__/\n' > .gitignore
cat > README.md <<'EOF'
# fares

交通運賃の計算ライブラリ。
EOF
cat > fares/__init__.py <<'EOF'
"""交通運賃の計算ライブラリ。"""

__version__ = "1.0.0.dev0"
EOF
commit "初期構成"

# ---- 2 ----
cat > data/stations.json <<'EOF'
{
  "lines": [
    {
      "id": "honsen",
      "name": "本線",
      "kind": "trunk",
      "stations": [
        ["中央", 0.0],
        ["北浜", 2.4],
        ["青葉", 4.1],
        ["桜台", 6.8],
        ["西町", 9.0],
        ["川辺", 11.3],
        ["港南", 14.6],
        ["緑ヶ丘", 17.2],
        ["東山", 19.5],
        ["新田", 23.0],
        ["大原", 27.4],
        ["高森", 31.8],
        ["白石", 36.5]
      ]
    }
  ]
}
EOF
commit "data: 本線の駅とキロ程を追加"

# ---- 3 ----
cat > fares/loader.py <<'EOF'
"""運賃データ (data/*.json) の読み込み。"""

import json
import os
from pathlib import Path

DEFAULT_DATA_DIR = Path(__file__).resolve().parent.parent / "data"


def data_dir():
    """データの置き場所。環境変数 FARES_DATA_DIR で差し替えられる。"""
    return Path(os.environ.get("FARES_DATA_DIR", DEFAULT_DATA_DIR))


def load(name):
    """data/<name>.json を読み込んで返す。"""
    path = data_dir() / f"{name}.json"
    with open(path, encoding="utf-8") as f:
        return json.load(f)
EOF
commit "feat: データの読み込み"

# ---- 4 ----
cat > fares/network.py <<'EOF'
"""路線網と経路の距離。

距離は 0.1 km 単位の整数 (units) で扱い、浮動小数の誤差を避ける。
"""

import heapq

from . import loader

TRUNK = "trunk"  # 幹線
LOCAL = "local"  # 地方交通線


def to_units(km):
    """km (小数 1 桁) を 0.1 km 単位の整数にする。"""
    return int(round(km * 10))


class UnknownStation(KeyError):
    """路線網にない駅。"""


class Route:
    """経路。駅の並びと、幹線・地方交通線それぞれの距離 (units)。"""

    def __init__(self, stations, trunk_units, local_units):
        self.stations = stations
        self.trunk_units = trunk_units
        self.local_units = local_units

    @property
    def total_units(self):
        return self.trunk_units + self.local_units


class Network:
    def __init__(self, lines):
        self.lines = lines
        self._edges = {}
        for line in lines:
            stations = line["stations"]
            for (a, km_a), (b, km_b) in zip(stations, stations[1:]):
                length = to_units(km_b) - to_units(km_a)
                if length <= 0:
                    raise ValueError(f"{line['name']}: {a} から {b} の距離が正でない")
                self._add_edge(a, b, length, line["kind"])
                self._add_edge(b, a, length, line["kind"])

    def _add_edge(self, a, b, length, kind):
        self._edges.setdefault(a, []).append((b, length, kind))

    @classmethod
    def load(cls):
        return cls(loader.load("stations")["lines"])

    def stations(self):
        return sorted(self._edges)

    def route(self, origin, destination):
        """営業キロが最短の経路を返す。"""
        for name in (origin, destination):
            if name not in self._edges:
                raise UnknownStation(name)
        # (距離, 幹線の距離, 地方交通線の距離, 駅, ここまでの駅)
        queue = [(0, 0, 0, origin, (origin,))]
        settled = {}
        while queue:
            dist, trunk, local, here, path = heapq.heappop(queue)
            if here == destination:
                return Route(list(path), trunk, local)
            if here in settled and settled[here] <= dist:
                continue
            settled[here] = dist
            for nxt, length, kind in self._edges[here]:
                if nxt in path:
                    continue
                if kind == TRUNK:
                    item = (dist + length, trunk + length, local, nxt, path + (nxt,))
                else:
                    item = (dist + length, trunk, local + length, nxt, path + (nxt,))
                heapq.heappush(queue, item)
        raise ValueError(f"{origin} から {destination} への経路がない")
EOF
commit "feat: 路線網と最短経路"

# ---- 5 ----
: > tests/__init__.py
cat > tests/test_network.py <<'EOF'
import unittest

from fares.network import Network, UnknownStation, to_units


class NetworkTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.net = Network.load()

    def test_to_units(self):
        self.assertEqual(to_units(2.4), 24)
        self.assertEqual(to_units(6.8), 68)
        self.assertEqual(to_units(0.0), 0)

    def test_route_on_one_line(self):
        route = self.net.route("中央", "西町")
        self.assertEqual(route.stations, ["中央", "北浜", "青葉", "桜台", "西町"])
        self.assertEqual(route.trunk_units, 90)
        self.assertEqual(route.local_units, 0)

    def test_route_is_symmetric(self):
        a = self.net.route("青葉", "大原")
        b = self.net.route("大原", "青葉")
        self.assertEqual(a.total_units, b.total_units)
        self.assertEqual(a.stations, list(reversed(b.stations)))

    def test_unknown_station(self):
        with self.assertRaises(UnknownStation):
            self.net.route("中央", "どこか")
EOF
commit "test: 路線網のテスト"

# ---- 6 ----
cat > data/fare_table.json <<'EOF'
{
  "effective": "2025-04-01",
  "tables": {
    "trunk": [
      {"min_km": 1, "max_km": 3, "fare": 150},
      {"min_km": 4, "max_km": 6, "fare": 190},
      {"min_km": 7, "max_km": 10, "fare": 200},
      {"min_km": 11, "max_km": 15, "fare": 240},
      {"min_km": 16, "max_km": 20, "fare": 310},
      {"min_km": 21, "max_km": 25, "fare": 400},
      {"min_km": 26, "max_km": 30, "fare": 480},
      {"min_km": 31, "max_km": 35, "fare": 570},
      {"min_km": 36, "max_km": 40, "fare": 660},
      {"min_km": 41, "max_km": 45, "fare": 750},
      {"min_km": 46, "max_km": 50, "fare": 840},
      {"min_km": 51, "max_km": 60, "fare": 990},
      {"min_km": 61, "max_km": 70, "fare": 1170},
      {"min_km": 71, "max_km": 80, "fare": 1340},
      {"min_km": 81, "max_km": 90, "fare": 1520},
      {"min_km": 91, "max_km": 100, "fare": 1690}
    ]
  }
}
EOF
commit "data: 幹線の運賃表"

# ---- 7 ----
cat > fares/tables.py <<'EOF'
"""距離帯ごとの運賃表 (data/fare_table.json)。"""

from bisect import bisect_right

from . import loader


class FareTable:
    """運賃計算キロ (整数の km) から運賃を引く表。

    rows は {"min_km", "max_km", "fare"} の並びで、min_km の昇順とする。
    """

    def __init__(self, name, rows):
        self.name = name
        self.rows = rows
        self._starts = [row["min_km"] for row in rows]

    def lookup(self, km):
        if km < self.rows[0]["min_km"]:
            km = self.rows[0]["min_km"]
        if km > self.rows[-1]["max_km"]:
            raise ValueError(f"{self.name}: {km} km は運賃表の範囲外")
        i = bisect_right(self._starts, km) - 1
        return self.rows[i]["fare"]


def load_tables():
    data = loader.load("fare_table")
    return {name: FareTable(name, rows) for name, rows in data["tables"].items()}
EOF
commit "feat: 運賃表の検索"

# ---- 8 ----
cat > tests/test_tables.py <<'EOF'
import unittest

from fares.tables import FareTable, load_tables

ROWS = [
    {"min_km": 1, "max_km": 3, "fare": 150},
    {"min_km": 4, "max_km": 6, "fare": 190},
    {"min_km": 7, "max_km": 10, "fare": 200},
]


class FareTableTest(unittest.TestCase):
    def setUp(self):
        self.table = FareTable("demo", ROWS)

    def test_inside_band(self):
        self.assertEqual(self.table.lookup(2), 150)
        self.assertEqual(self.table.lookup(5), 190)
        self.assertEqual(self.table.lookup(8), 200)

    def test_band_edges(self):
        self.assertEqual(self.table.lookup(3), 150)
        self.assertEqual(self.table.lookup(4), 190)
        self.assertEqual(self.table.lookup(6), 190)
        self.assertEqual(self.table.lookup(7), 200)
        self.assertEqual(self.table.lookup(10), 200)

    def test_below_first_band(self):
        self.assertEqual(self.table.lookup(0), 150)

    def test_out_of_range(self):
        with self.assertRaises(ValueError):
            self.table.lookup(11)


class LoadedTablesTest(unittest.TestCase):
    def test_trunk_is_loaded(self):
        tables = load_tables()
        self.assertIn("trunk", tables)
        self.assertEqual(tables["trunk"].lookup(1), 150)
EOF
commit "test: 運賃表のテスト"

# ---- 9 ----
cat > fares/calculator.py <<'EOF'
"""運賃の計算。"""

from . import network, tables


class Quote:
    """運賃の計算結果。"""

    def __init__(self, route, km, table_name, amount):
        self.route = route
        self.km = km
        self.table_name = table_name
        self.amount = amount


def fare_km(route):
    """運賃計算キロ (1 km 未満の端数は切り上げ) と、使う運賃表の名前を返す。"""
    return -(-route.total_units // 10), "trunk"


class Calculator:
    def __init__(self, net=None, fare_tables=None):
        self.network = net or network.Network.load()
        self.tables = fare_tables or tables.load_tables()

    def quote(self, origin, destination):
        if origin == destination:
            raise ValueError("発駅と着駅が同じ")
        route = self.network.route(origin, destination)
        km, table_name = fare_km(route)
        amount = self.tables[table_name].lookup(km)
        return Quote(route, km, table_name, amount)
EOF
cat > fares/__init__.py <<'EOF'
"""交通運賃の計算ライブラリ。"""

from .calculator import Calculator

__version__ = "1.0.0.dev0"

_calculator = None


def quote(origin, destination):
    """運賃の計算結果 (Quote) を返す。"""
    global _calculator
    if _calculator is None:
        _calculator = Calculator()
    return _calculator.quote(origin, destination)


def fare(origin, destination):
    """運賃 (円) を返す。"""
    return quote(origin, destination).amount
EOF
commit "feat: 運賃の計算"

# ---- 10 ----
cat > tests/test_calculator.py <<'EOF'
import unittest

from fares import fare
from fares.calculator import fare_km
from fares.network import Route


class FareKmTest(unittest.TestCase):
    def test_rounds_up_fraction(self):
        self.assertEqual(fare_km(Route(["a", "b"], 41, 0))[0], 5)
        self.assertEqual(fare_km(Route(["a", "b"], 40, 0))[0], 4)
        self.assertEqual(fare_km(Route(["a", "b"], 1, 0))[0], 1)


class TrunkFareTest(unittest.TestCase):
    def test_short_distance(self):
        self.assertEqual(fare("中央", "北浜"), 150)
        self.assertEqual(fare("中央", "青葉"), 190)

    def test_middle_distance(self):
        self.assertEqual(fare("中央", "西町"), 200)
        self.assertEqual(fare("北浜", "川辺"), 200)
        self.assertEqual(fare("中央", "川辺"), 240)
        self.assertEqual(fare("青葉", "港南"), 240)

    def test_same_station(self):
        with self.assertRaises(ValueError):
            fare("中央", "中央")
EOF
commit "test: 運賃計算のテスト"

# ---- 11 ----
cat > fares/cli.py <<'EOF'
"""コマンドライン: python3 -m fares <発駅> <着駅>"""

import argparse
import sys

from . import quote
from .network import UnknownStation


def build_parser():
    parser = argparse.ArgumentParser(prog="fares", description="2 駅間の運賃を表示する")
    parser.add_argument("origin", help="発駅")
    parser.add_argument("destination", help="着駅")
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        q = quote(args.origin, args.destination)
    except UnknownStation as e:
        print(f"駅が見つからない: {e.args[0]}", file=sys.stderr)
        return 2
    except ValueError as e:
        print(f"エラー: {e}", file=sys.stderr)
        return 2
    print(f"{args.origin} → {args.destination}  {q.km} km  {q.amount} 円")
    return 0
EOF
cat > fares/__main__.py <<'EOF'
import sys

from .cli import main

sys.exit(main())
EOF
commit "feat: コマンドラインから運賃を表示する"

# ---- 12 ----
sub data/stations.json <<'EOF'
        ["白石", 36.5]
      ]
    }
  ]
=====
        ["白石", 36.5]
      ]
    },
    {
      "id": "yamate",
      "name": "山手支線",
      "kind": "local",
      "stations": [
        ["西町", 0.0],
        ["柳原", 3.2],
        ["石川", 7.5],
        ["山口", 11.9],
        ["奥森", 16.4]
      ]
    }
  ]
EOF
commit "data: 山手支線を追加"

# ---- 13 ----
sub data/fare_table.json <<'EOF'
      {"min_km": 91, "max_km": 100, "fare": 1690}
    ]
=====
      {"min_km": 91, "max_km": 100, "fare": 1690}
    ],
    "local": [
      {"min_km": 1, "max_km": 3, "fare": 150},
      {"min_km": 4, "max_km": 6, "fare": 190},
      {"min_km": 7, "max_km": 10, "fare": 210},
      {"min_km": 11, "max_km": 15, "fare": 250},
      {"min_km": 16, "max_km": 20, "fare": 330},
      {"min_km": 21, "max_km": 25, "fare": 420},
      {"min_km": 26, "max_km": 30, "fare": 500},
      {"min_km": 31, "max_km": 35, "fare": 590},
      {"min_km": 36, "max_km": 40, "fare": 680}
    ]
EOF
commit "data: 地方交通線の運賃表"

# ---- 14 ----
sub fares/calculator.py <<'EOF'
def fare_km(route):
    """運賃計算キロ (1 km 未満の端数は切り上げ) と、使う運賃表の名前を返す。"""
    return -(-route.total_units // 10), "trunk"
=====
# 地方交通線の営業キロを幹線の距離に換算する倍率 (換算キロ = 営業キロ × 1.1)
LOCAL_RATIO = (11, 10)


def _ceil_div(a, b):
    return -(-a // b)


def fare_km(route):
    """運賃計算キロ (1 km 未満の端数は切り上げ) と、使う運賃表の名前を返す。

    地方交通線だけの経路は、営業キロで地方交通線の表を使う。
    幹線を含む経路は、地方交通線の区間を換算キロ (0.1 km 未満は切り上げ) にして
    幹線の距離に足し、幹線の表を使う。
    """
    if route.trunk_units == 0:
        return _ceil_div(route.local_units, 10), "local"
    num, den = LOCAL_RATIO
    units = route.trunk_units + _ceil_div(route.local_units * num, den)
    return _ceil_div(units, 10), "trunk"
EOF
commit "feat: 地方交通線と換算キロに対応"

# ---- 15 ----
sub tests/test_calculator.py <<'EOF'
        self.assertEqual(fare_km(Route(["a", "b"], 1, 0))[0], 1)
=====
        self.assertEqual(fare_km(Route(["a", "b"], 1, 0))[0], 1)

    def test_local_only_uses_local_table(self):
        self.assertEqual(fare_km(Route(["a", "b"], 0, 132)), (14, "local"))

    def test_mixed_route_converts_local_distance(self):
        # 9.0 km + 3.2 km × 1.1 (= 3.52 → 3.6 km) = 12.6 km → 13 km
        self.assertEqual(fare_km(Route(["a", "b", "c"], 90, 32)), (13, "trunk"))
EOF
cat >> tests/test_calculator.py <<'EOF'


class LocalFareTest(unittest.TestCase):
    def test_local_only(self):
        self.assertEqual(fare("柳原", "奥森"), 250)
        self.assertEqual(fare("西町", "石川"), 210)

    def test_mixed(self):
        self.assertEqual(fare("中央", "柳原"), 240)
EOF
commit "test: 地方交通線を含む経路のテスト"

# ---- 16 ----
cat > fares/passengers.py <<'EOF'
"""旅客の区分ごとの運賃。"""

ADULT = "adult"
CHILD = "child"
KINDS = (ADULT, CHILD)


def floor_to_ten(yen):
    """10 円未満を切り捨てる。"""
    return int(yen) // 10 * 10


def apply(kind, adult_fare):
    """大人の運賃から、旅客の区分に応じた運賃を求める。"""
    if kind == ADULT:
        return adult_fare
    if kind == CHILD:
        return floor_to_ten(adult_fare / 2)
    raise ValueError(f"未知の旅客の区分: {kind}")
EOF
sub fares/calculator.py <<'EOF'
from . import network, tables
=====
from . import network, passengers, tables
EOF
sub fares/calculator.py <<'EOF'
    def __init__(self, route, km, table_name, amount):
        self.route = route
        self.km = km
        self.table_name = table_name
        self.amount = amount
=====
    def __init__(self, route, km, table_name, passenger, adult, amount):
        self.route = route
        self.km = km
        self.table_name = table_name
        self.passenger = passenger
        self.adult = adult
        self.amount = amount
EOF
sub fares/calculator.py <<'EOF'
    def quote(self, origin, destination):
        if origin == destination:
            raise ValueError("発駅と着駅が同じ")
        route = self.network.route(origin, destination)
        km, table_name = fare_km(route)
        amount = self.tables[table_name].lookup(km)
        return Quote(route, km, table_name, amount)
=====
    def quote(self, origin, destination, passenger=passengers.ADULT):
        if origin == destination:
            raise ValueError("発駅と着駅が同じ")
        route = self.network.route(origin, destination)
        km, table_name = fare_km(route)
        adult = self.tables[table_name].lookup(km)
        amount = passengers.apply(passenger, adult)
        return Quote(route, km, table_name, passenger, adult, amount)
EOF
sub fares/__init__.py <<'EOF'
def quote(origin, destination):
    """運賃の計算結果 (Quote) を返す。"""
    global _calculator
    if _calculator is None:
        _calculator = Calculator()
    return _calculator.quote(origin, destination)


def fare(origin, destination):
    """運賃 (円) を返す。"""
    return quote(origin, destination).amount
=====
def quote(origin, destination, passenger="adult"):
    """運賃の計算結果 (Quote) を返す。passenger は "adult" か "child"。"""
    global _calculator
    if _calculator is None:
        _calculator = Calculator()
    return _calculator.quote(origin, destination, passenger)


def fare(origin, destination, passenger="adult"):
    """運賃 (円) を返す。"""
    return quote(origin, destination, passenger).amount
EOF
sub fares/cli.py <<'EOF'
from . import quote
from .network import UnknownStation
=====
from . import passengers, quote
from .network import UnknownStation
EOF
sub fares/cli.py <<'EOF'
    parser.add_argument("destination", help="着駅")
    return parser
=====
    parser.add_argument("destination", help="着駅")
    parser.add_argument("--passenger", default=passengers.ADULT, choices=passengers.KINDS, help="旅客の区分")
    return parser
EOF
sub fares/cli.py <<'EOF'
        q = quote(args.origin, args.destination)
=====
        q = quote(args.origin, args.destination, args.passenger)
EOF
commit "feat: 子供運賃"

# ---- 17 ----
cat > tests/test_passengers.py <<'EOF'
import unittest

from fares import fare, passengers


class PassengersTest(unittest.TestCase):
    def test_adult_is_unchanged(self):
        self.assertEqual(passengers.apply("adult", 240), 240)

    def test_child_is_half(self):
        self.assertEqual(passengers.apply("child", 200), 100)
        self.assertEqual(passengers.apply("child", 240), 120)

    def test_unknown_kind(self):
        with self.assertRaises(ValueError):
            passengers.apply("senior", 200)


class ChildFareTest(unittest.TestCase):
    def test_child_fares(self):
        self.assertEqual(fare("中央", "北浜", "child"), 70)
        self.assertEqual(fare("中央", "西町", "child"), 100)
        self.assertEqual(fare("中央", "川辺", "child"), 120)
EOF
commit "test: 子供運賃のテスト"

# ---- 18 ----
sub data/stations.json <<'EOF'
        ["奥森", 16.4]
      ]
    }
  ]
=====
        ["奥森", 16.4]
      ]
    },
    {
      "id": "kuko",
      "name": "空港線",
      "kind": "trunk",
      "stations": [
        ["川辺", 0.0],
        ["臨海", 3.1],
        ["空港", 6.2]
      ]
    }
  ]
EOF
commit "data: 空港線を追加"

# ---- 19 ----
cat > data/surcharges.json <<'EOF'
{
  "stations": {
    "空港": 130
  }
}
EOF
cat > fares/surcharges.py <<'EOF'
"""加算運賃 (特定の駅を発着する場合に運賃へ加える額)。"""

from . import loader


def load_surcharges():
    return loader.load("surcharges")["stations"]


def surcharge_for(route, table):
    """発駅と着駅の加算運賃の合計を返す。"""
    ends = {route.stations[0], route.stations[-1]}
    return sum(table.get(name, 0) for name in sorted(ends))
EOF
sub fares/calculator.py <<'EOF'
from . import network, passengers, tables
=====
from . import network, passengers, surcharges, tables
EOF
sub fares/calculator.py <<'EOF'
    def __init__(self, route, km, table_name, passenger, adult, amount):
        self.route = route
        self.km = km
        self.table_name = table_name
=====
    def __init__(self, route, km, table_name, base, surcharge, passenger, adult, amount):
        self.route = route
        self.km = km
        self.table_name = table_name
        self.base = base
        self.surcharge = surcharge
EOF
sub fares/calculator.py <<'EOF'
    def __init__(self, net=None, fare_tables=None):
        self.network = net or network.Network.load()
        self.tables = fare_tables or tables.load_tables()
=====
    def __init__(self, net=None, fare_tables=None, surcharge_table=None):
        self.network = net or network.Network.load()
        self.tables = fare_tables or tables.load_tables()
        if surcharge_table is None:
            surcharge_table = surcharges.load_surcharges()
        self.surcharges = surcharge_table
EOF
sub fares/calculator.py <<'EOF'
        adult = self.tables[table_name].lookup(km)
        amount = passengers.apply(passenger, adult)
        return Quote(route, km, table_name, passenger, adult, amount)
=====
        base = self.tables[table_name].lookup(km)
        extra = surcharges.surcharge_for(route, self.surcharges)
        adult = base + extra
        amount = passengers.apply(passenger, adult)
        return Quote(route, km, table_name, base, extra, passenger, adult, amount)
EOF
commit "feat: 加算運賃"

# ---- 20 ----
cat > tests/test_surcharges.py <<'EOF'
import unittest

from fares import fare, quote
from fares.network import Route
from fares.surcharges import surcharge_for


class SurchargeTest(unittest.TestCase):
    def test_surcharge_for_ends(self):
        table = {"x": 100, "y": 30}
        self.assertEqual(surcharge_for(Route(["x", "m", "z"], 10, 0), table), 100)
        self.assertEqual(surcharge_for(Route(["z", "m", "y"], 10, 0), table), 30)
        self.assertEqual(surcharge_for(Route(["x", "m", "y"], 10, 0), table), 130)
        self.assertEqual(surcharge_for(Route(["z", "x", "w"], 10, 0), table), 0)

    def test_airport(self):
        q = quote("川辺", "空港")
        self.assertEqual(q.base, 200)
        self.assertEqual(q.surcharge, 130)
        self.assertEqual(q.amount, 330)
        self.assertEqual(fare("臨海", "空港"), 320)

    def test_airport_child(self):
        self.assertEqual(fare("川辺", "空港", "child"), 160)
EOF
commit "test: 加算運賃のテスト"

# ---- 21 ----
cat >> README.md <<'EOF'

## 使い方

```
python3 -m fares 中央 西町
python3 -m fares 中央 西町 --passenger child
```

Python から:

```python
import fares
fares.fare("中央", "西町")            # 大人の運賃 (円)
fares.quote("中央", "西町").km        # 運賃計算キロ
```

## データ

- `data/stations.json`: 路線と駅のキロ程
- `data/fare_table.json`: 距離帯ごとの運賃表 (幹線 `trunk`、地方交通線 `local`)
- `data/surcharges.json`: 加算運賃

## テスト

```
python3 -m unittest discover -s tests -t .
```
EOF
commit "docs: README に使い方を追記"

# ---- 22: v2.0 ----
sub fares/__init__.py <<'EOF'
__version__ = "1.0.0.dev0"
=====
__version__ = "2.0.0"
EOF
commit "release: 2.0.0"
git tag v2.0

# ---- 23 ----
cat > CHANGELOG.md <<'EOF'
# 変更履歴

## 2.0.0

- 地方交通線と換算キロに対応
- 子供運賃
- 加算運賃 (空港)
EOF
commit "docs: CHANGELOG を追加"

# ---- 24 ----
sub data/stations.json <<'EOF'
        ["白石", 36.5]
=====
        ["白石", 36.5],
        ["若葉", 41.2],
        ["宮前", 45.9]
EOF
commit "data: 本線を宮前まで延伸"

# ---- 25 ----
sub fares/passengers.py <<'EOF'
CHILD = "child"
KINDS = (ADULT, CHILD)
=====
CHILD = "child"
DISABLED = "disabled"  # 障害者割引
KINDS = (ADULT, CHILD, DISABLED)
EOF
sub fares/passengers.py <<'EOF'
    if kind == CHILD:
        return floor_to_ten(adult_fare / 2)
=====
    if kind in (CHILD, DISABLED):
        # 子供運賃と障害者割引は、どちらも大人の運賃の半額
        return floor_to_ten(adult_fare / 2)
EOF
sub fares/__init__.py <<'EOF'
    """運賃の計算結果 (Quote) を返す。passenger は "adult" か "child"。"""
=====
    """運賃の計算結果 (Quote) を返す。passenger は "adult"、"child"、"disabled" のいずれか。"""
EOF
commit "feat: 障害者割引"

# ---- 26 ----
sub tests/test_passengers.py <<'EOF'
    def test_unknown_kind(self):
=====
    def test_disabled_is_half(self):
        self.assertEqual(passengers.apply("disabled", 240), 120)
        self.assertEqual(fare("中央", "北浜", "disabled"), 70)

    def test_unknown_kind(self):
EOF
commit "test: 障害者割引のテスト"

# ---- 27 ----
sub fares/cli.py <<'EOF'
    parser.add_argument("--passenger", default=passengers.ADULT, choices=passengers.KINDS, help="旅客の区分")
    return parser
=====
    parser.add_argument("--passenger", default=passengers.ADULT, choices=passengers.KINDS, help="旅客の区分")
    parser.add_argument("--route", action="store_true", help="経路の駅も表示する")
    return parser
EOF
sub fares/cli.py <<'EOF'
    print(f"{args.origin} → {args.destination}  {q.km} km  {q.amount} 円")
    return 0
=====
    print(f"{args.origin} → {args.destination}  {q.km} km  {q.amount} 円")
    if args.route:
        print("経路: " + " - ".join(q.route.stations))
    return 0
EOF
commit "feat: --route で経路の駅を表示する"

# ---- 28 ----
sub data/stations.json <<'EOF'
        ["石川", 7.5],
=====
        ["石川", 7.6],
EOF
commit "data: 山手支線のキロ程を修正"

# ---- 29 ----
sub tests/test_network.py <<'EOF'
    def test_unknown_station(self):
=====
    def test_extension(self):
        route = self.net.route("白石", "宮前")
        self.assertEqual(route.stations, ["白石", "若葉", "宮前"])
        self.assertEqual(route.trunk_units, 94)

    def test_branch_route(self):
        route = self.net.route("北浜", "柳原")
        self.assertEqual(route.stations, ["北浜", "青葉", "桜台", "西町", "柳原"])
        self.assertEqual((route.trunk_units, route.local_units), (66, 32))

    def test_unknown_station(self):
EOF
commit "test: 延伸区間と支線の経路のテスト"

# ---- 30: ここから 3 コミットは import できない ----
cat > fares/rounding.py <<'EOF'
"""運賃の端数処理。"""

UNIT = 10  # 運賃は 10 円単位


def round_yen(yen, unit=UNIT):
    """unit 円未満を切り捨てる。"""
    return int(yen) // unit * unit
EOF
sub fares/passengers.py <<'EOF'
"""旅客の区分ごとの運賃。"""
=====
"""旅客の区分ごとの運賃。"""

from .rounding import round_fare
EOF
sub fares/passengers.py <<'EOF'
def floor_to_ten(yen):
    """10 円未満を切り捨てる。"""
    return int(yen) // 10 * 10


=====
EOF
sub fares/passengers.py <<'EOF'
        return floor_to_ten(adult_fare / 2)
=====
        return round_fare(adult_fare / 2)
EOF
sub fares/calculator.py <<'EOF'
from . import network, passengers, surcharges, tables
=====
from . import network, passengers, rounding, surcharges, tables
EOF
sub fares/calculator.py <<'EOF'
        adult = base + extra
=====
        adult = rounding.round_yen(base + extra)
EOF
commit "refactor: 端数処理を rounding モジュールへ分ける"

# ---- 31 ----
sub fares/cli.py <<'EOF'
import argparse
import sys
=====
import argparse
import json
import sys
EOF
sub fares/cli.py <<'EOF'
    parser.add_argument("--route", action="store_true", help="経路の駅も表示する")
=====
    parser.add_argument("--route", action="store_true", help="経路の駅も表示する")
    parser.add_argument("--json", action="store_true", help="結果を JSON で出力する")
EOF
sub fares/cli.py <<'EOF'
    print(f"{args.origin} → {args.destination}  {q.km} km  {q.amount} 円")
=====
    if args.json:
        result = {
            "origin": q.route.stations[0],
            "destination": q.route.stations[-1],
            "km": q.km,
            "passenger": q.passenger,
            "fare": q.amount,
            "route": q.route.stations,
        }
        print(json.dumps(result, ensure_ascii=False))
        return 0
    print(f"{args.origin} → {args.destination}  {q.km} km  {q.amount} 円")
EOF
commit "feat: --json で結果を JSON で出力する"

# ---- 32 ----
sub data/surcharges.json <<'EOF'
    "空港": 130
=====
    "空港": 150
EOF
sub tests/test_surcharges.py <<'EOF'
        self.assertEqual(q.surcharge, 130)
        self.assertEqual(q.amount, 330)
        self.assertEqual(fare("臨海", "空港"), 320)
=====
        self.assertEqual(q.surcharge, 150)
        self.assertEqual(q.amount, 350)
        self.assertEqual(fare("臨海", "空港"), 340)
EOF
sub tests/test_surcharges.py <<'EOF'
        self.assertEqual(fare("川辺", "空港", "child"), 160)
=====
        self.assertEqual(fare("川辺", "空港", "child"), 170)
EOF
commit "data: 空港の加算運賃を改定"

# ---- 33 ----
sub fares/passengers.py <<'EOF'
from .rounding import round_fare
=====
from .rounding import round_yen
EOF
sub fares/passengers.py <<'EOF'
        return round_fare(adult_fare / 2)
=====
        return round_yen(adult_fare / 2)
EOF
commit "fix: passengers の import を直す"

# ---- 34 ----
cat > tests/test_rounding.py <<'EOF'
import unittest

from fares.rounding import round_yen


class RoundYenTest(unittest.TestCase):
    def test_multiple_of_ten_is_unchanged(self):
        self.assertEqual(round_yen(80), 80)
        self.assertEqual(round_yen(240), 240)

    def test_fraction(self):
        self.assertEqual(round_yen(75), 70)
        self.assertEqual(round_yen(79.9), 70)
        self.assertEqual(round_yen(81), 80)

    def test_unit(self):
        self.assertEqual(round_yen(123, unit=5), 120)
EOF
commit "test: 端数処理のテスト"

# ---- 35 ----
sub fares/network.py <<'EOF'
            for nxt, length, kind in self._edges[here]:
                if nxt in path:
                    continue
=====
            for nxt, length, kind in self._edges[here]:
                if nxt in settled:
                    continue
EOF
commit "refactor: 経路探索で確定済みの駅を再訪しない"

# ---- 36 ----
sub CHANGELOG.md <<'EOF'
# 変更履歴

=====
# 変更履歴

## 2.1.0

- 本線を宮前まで延伸
- 障害者割引
- `--route`、`--json`
- 空港の加算運賃を改定

EOF
commit "docs: CHANGELOG を更新"

# ---- 37 ----
sub fares/network.py <<'EOF'
class UnknownStation(KeyError):
=====
def normalize(name):
    """駅名の表記ゆれ (前後の空白、「ケ」と「ヶ」) をそろえる。"""
    return name.strip().replace("ケ", "ヶ")


class UnknownStation(KeyError):
EOF
sub fares/network.py <<'EOF'
        """営業キロが最短の経路を返す。"""
=====
        """営業キロが最短の経路を返す。"""
        origin, destination = normalize(origin), normalize(destination)
EOF
commit "feat: 駅名の表記ゆれを吸収する"

# ---- 38 ----
sub tests/test_network.py <<'EOF'
    def test_unknown_station(self):
=====
    def test_normalizes_station_names(self):
        route = self.net.route(" 東山", "緑ケ丘")
        self.assertEqual(route.stations, ["東山", "緑ヶ丘"])

    def test_unknown_station(self):
EOF
commit "test: 駅名の表記ゆれのテスト"

# ---- 39 ----
sub fares/__init__.py <<'EOF'
__version__ = "2.0.0"
=====
__version__ = "2.1.0"
EOF
commit "release: 2.1.0"

# ---- 40 ----
python3 - <<'PY'
import json
path = "data/fare_table.json"
with open(path, encoding="utf-8") as f:
    data = json.load(f)
data["effective"] = "2026-06-01"
revised = {16: 320, 21: 420, 26: 500, 31: 590, 36: 680, 41: 780, 46: 870, 51: 1020, 61: 1210, 71: 1390, 81: 1570, 91: 1740}
for row in data["tables"]["trunk"]:
    if row["min_km"] in revised:
        row["fare"] = revised[row["min_km"]]
    if row["min_km"] == 16:
        row["min_km"] = 15
with open(path, "w", encoding="utf-8") as f:
    f.write(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
PY
commit "data: 運賃表を改定する"

# ---- 41 ----
cat >> tests/test_calculator.py <<'EOF'


class LongDistanceFareTest(unittest.TestCase):
    def test_long_distance(self):
        self.assertEqual(fare("中央", "東山"), 320)
        self.assertEqual(fare("青葉", "大原"), 420)
        self.assertEqual(fare("中央", "宮前"), 870)
EOF
commit "test: 長距離の運賃のテスト"

# ---- 42 ----
sub fares/__init__.py <<'EOF'
def fare(origin, destination, passenger="adult"):
    """運賃 (円) を返す。"""
    return quote(origin, destination, passenger).amount
=====
def fare(origin, destination, passenger="adult"):
    """運賃 (円) を返す。"""
    return quote(origin, destination, passenger).amount


def round_trip_fare(origin, destination, passenger="adult"):
    """往復の運賃 (円) を返す。行きと帰りの運賃の合計。"""
    return fare(origin, destination, passenger) + fare(destination, origin, passenger)
EOF
sub fares/cli.py <<'EOF'
from . import passengers, quote
=====
from . import passengers, quote, round_trip_fare
EOF
sub fares/cli.py <<'EOF'
    parser.add_argument("--json", action="store_true", help="結果を JSON で出力する")
=====
    parser.add_argument("--json", action="store_true", help="結果を JSON で出力する")
    parser.add_argument("--round-trip", action="store_true", help="往復の運賃も表示する")
EOF
sub fares/cli.py <<'EOF'
    if args.route:
        print("経路: " + " - ".join(q.route.stations))
=====
    if args.round_trip:
        print(f"往復: {round_trip_fare(args.origin, args.destination, args.passenger)} 円")
    if args.route:
        print("経路: " + " - ".join(q.route.stations))
EOF
commit "feat: 往復運賃"

# ---- 43 ----
sub tests/test_calculator.py <<'EOF'
from fares import fare
=====
from fares import fare, round_trip_fare
EOF
sub tests/test_calculator.py <<'EOF'
    def test_same_station(self):
=====
    def test_round_trip(self):
        self.assertEqual(round_trip_fare("中央", "西町"), 400)
        self.assertEqual(round_trip_fare("中央", "西町", "child"), 200)

    def test_same_station(self):
EOF
commit "test: 往復運賃のテスト"

# ---- 44 ----
sub README.md <<'EOF'
python3 -m fares 中央 西町 --passenger child
=====
python3 -m fares 中央 西町 --passenger child
python3 -m fares 中央 西町 --round-trip
EOF
commit "docs: README に往復運賃を追記"

# ---- 45 ----
python3 - <<'PY'
import json
path = "data/fare_table.json"
with open(path, encoding="utf-8") as f:
    data = json.load(f)
revised = {4: 200, 7: 220, 11: 260, 16: 340, 21: 440, 26: 520, 31: 610, 36: 700}
for row in data["tables"]["local"]:
    if row["min_km"] in revised:
        row["fare"] = revised[row["min_km"]]
with open(path, "w", encoding="utf-8") as f:
    f.write(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
PY
sub tests/test_calculator.py <<'EOF'
        self.assertEqual(fare("柳原", "奥森"), 250)
        self.assertEqual(fare("西町", "石川"), 210)
=====
        self.assertEqual(fare("柳原", "奥森"), 260)
        self.assertEqual(fare("西町", "石川"), 220)
EOF
commit "data: 地方交通線の運賃表を改定"

# ---- 46 ----
sub fares/cli.py <<'EOF'
def main(argv=None):
=====
def format_text(args, q):
    lines = [f"{args.origin} → {args.destination}  {q.km} km  {q.amount} 円"]
    if args.round_trip:
        lines.append(f"往復: {round_trip_fare(args.origin, args.destination, args.passenger)} 円")
    if args.route:
        lines.append("経路: " + " - ".join(q.route.stations))
    return "\n".join(lines)


def main(argv=None):
EOF
sub fares/cli.py <<'EOF'
    print(f"{args.origin} → {args.destination}  {q.km} km  {q.amount} 円")
    if args.round_trip:
        print(f"往復: {round_trip_fare(args.origin, args.destination, args.passenger)} 円")
    if args.route:
        print("経路: " + " - ".join(q.route.stations))
    return 0
=====
    print(format_text(args, q))
    return 0
EOF
commit "refactor: CLI の表示を関数に分ける"

# ---- 47 ----
sub fares/cli.py <<'EOF'
from .network import UnknownStation
=====
from .network import Network, UnknownStation
EOF
sub fares/cli.py <<'EOF'
    parser.add_argument("origin", help="発駅")
    parser.add_argument("destination", help="着駅")
=====
    parser.add_argument("origin", nargs="?", help="発駅")
    parser.add_argument("destination", nargs="?", help="着駅")
    parser.add_argument("--list", action="store_true", help="駅の一覧を表示する")
EOF
sub fares/cli.py <<'EOF'
    args = build_parser().parse_args(argv)
    try:
=====
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.list:
        print("\n".join(Network.load().stations()))
        return 0
    if args.origin is None or args.destination is None:
        parser.error("発駅と着駅を指定する")
    try:
EOF
commit "feat: --list で駅の一覧を表示する"

# ---- 48 ----
cat > tests/test_cli.py <<'EOF'
import io
import json
import unittest
from contextlib import redirect_stderr, redirect_stdout

from fares.cli import main


def run(*argv):
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = main(list(argv))
    return code, out.getvalue(), err.getvalue()


class CliTest(unittest.TestCase):
    def test_text(self):
        code, out, _ = run("中央", "西町")
        self.assertEqual(code, 0)
        self.assertEqual(out.strip(), "中央 → 西町  9 km  200 円")

    def test_json(self):
        code, out, _ = run("中央", "川辺", "--json")
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["fare"], 240)

    def test_list(self):
        code, out, _ = run("--list")
        self.assertEqual(code, 0)
        self.assertIn("宮前", out.split())

    def test_unknown_station(self):
        code, _, err = run("中央", "どこか")
        self.assertEqual(code, 2)
        self.assertIn("どこか", err)
EOF
commit "test: CLI のテスト"

# ---- 49 ----
sub fares/__init__.py <<'EOF'
__version__ = "2.1.0"
=====
__version__ = "2.2.0"
EOF
commit "release: 2.2.0"

# ---- 50 ----
sub fares/calculator.py <<'EOF'
        if origin == destination:
            raise ValueError("発駅と着駅が同じ")
=====
        if network.normalize(origin) == network.normalize(destination):
            raise ValueError(f"発駅と着駅が同じ: {origin}")
EOF
commit "fix: 表記ゆれのある同じ駅を発着に指定したときもエラーにする"

# ---- 51 ----
sub fares/network.py <<'EOF'
        self.lines = lines
        self._edges = {}
=====
        self.lines = lines
        self._edges = {}
        self._routes = {}
EOF
sub fares/network.py <<'EOF'
        origin, destination = normalize(origin), normalize(destination)
        for name in (origin, destination):
=====
        origin, destination = normalize(origin), normalize(destination)
        key = (origin, destination)
        if key not in self._routes:
            self._routes[key] = self._search(origin, destination)
        return self._routes[key]

    def _search(self, origin, destination):
        for name in (origin, destination):
EOF
commit "perf: 経路探索の結果を覚えておく"

# ---- 52 ----
sub tests/test_network.py <<'EOF'
    def test_unknown_station(self):
=====
    def test_route_is_cached(self):
        self.assertIs(self.net.route("中央", "高森"), self.net.route("中央", "高森"))

    def test_unknown_station(self):
EOF
commit "test: 経路探索の結果のテスト"

# ---- 53 ----
sub CHANGELOG.md <<'EOF'
# 変更履歴

=====
# 変更履歴

## 2.2.0

- 運賃表を改定
- 地方交通線の運賃表を改定
- 往復運賃 (`--round-trip`)
- 駅の一覧 (`--list`)

EOF
commit "docs: CHANGELOG を更新"

# ---- 54 ----
sub fares/cli.py <<'EOF'
    parser.add_argument("--round-trip", action="store_true", help="往復の運賃も表示する")
=====
    parser.add_argument("--round-trip", action="store_true", help="往復の運賃も表示する")
    parser.add_argument("--detail", action="store_true", help="運賃の内訳も表示する")
EOF
sub fares/cli.py <<'EOF'
    if args.route:
        lines.append("経路: " + " - ".join(q.route.stations))
    return "\n".join(lines)
=====
    if args.route:
        lines.append("経路: " + " - ".join(q.route.stations))
    if args.detail:
        lines.append(f"内訳: 運賃表 {q.table_name} の {q.km} km = {q.base} 円、加算運賃 {q.surcharge} 円、大人 {q.adult} 円")
    return "\n".join(lines)
EOF
commit "feat: --detail で運賃の内訳を表示する"

# ---- 55 ----
sub tests/test_cli.py <<'EOF'
    def test_list(self):
=====
    def test_detail(self):
        code, out, _ = run("川辺", "空港", "--detail")
        self.assertEqual(code, 0)
        self.assertIn("内訳: 運賃表 trunk の 7 km = 200 円、加算運賃 150 円、大人 350 円", out)

    def test_list(self):
EOF
commit "test: 内訳の表示のテスト"

# ---- 56 ----
cat > fares/rounding.py <<'EOF'
"""運賃と距離の端数処理。"""

from decimal import ROUND_HALF_UP, ROUND_UP, Decimal

UNIT = 10  # 運賃は 10 円単位


def round_yen(yen, unit=UNIT):
    """unit 円未満を四捨五入する (5 円は切り上げ)。"""
    steps = (Decimal(str(yen)) / unit).quantize(Decimal(1), rounding=ROUND_HALF_UP)
    return int(steps) * unit


def ceil_km(units):
    """0.1 km 単位の距離を、1 km 未満を切り上げた km にする。"""
    return int((Decimal(units) / 10).quantize(Decimal(1), rounding=ROUND_UP))
EOF
sub fares/calculator.py <<'EOF'
    if route.trunk_units == 0:
        return _ceil_div(route.local_units, 10), "local"
    num, den = LOCAL_RATIO
    units = route.trunk_units + _ceil_div(route.local_units * num, den)
    return _ceil_div(units, 10), "trunk"
=====
    if route.trunk_units == 0:
        return rounding.ceil_km(route.local_units), "local"
    num, den = LOCAL_RATIO
    units = route.trunk_units + _ceil_div(route.local_units * num, den)
    return rounding.ceil_km(units), "trunk"
EOF
sub tests/test_rounding.py <<'EOF'
        self.assertEqual(round_yen(75), 70)
        self.assertEqual(round_yen(79.9), 70)
        self.assertEqual(round_yen(81), 80)

    def test_unit(self):
        self.assertEqual(round_yen(123, unit=5), 120)
=====
        self.assertEqual(round_yen(75), 80)
        self.assertEqual(round_yen(74.9), 70)
        self.assertEqual(round_yen(81), 80)

    def test_unit(self):
        self.assertEqual(round_yen(123, unit=5), 125)
EOF
sub tests/test_passengers.py <<'EOF'
        self.assertEqual(fare("中央", "北浜", "disabled"), 70)
=====
        self.assertEqual(fare("中央", "北浜", "disabled"), 80)
EOF
sub tests/test_passengers.py <<'EOF'
        self.assertEqual(fare("中央", "北浜", "child"), 70)
=====
        self.assertEqual(fare("中央", "北浜", "child"), 80)
EOF
sub tests/test_surcharges.py <<'EOF'
        self.assertEqual(fare("川辺", "空港", "child"), 170)
=====
        self.assertEqual(fare("川辺", "空港", "child"), 180)
EOF
commit "fix: 運賃の端数処理を見直す"

# ---- 57 ----
sub tests/test_rounding.py <<'EOF'
from fares.rounding import round_yen
=====
from fares.rounding import ceil_km, round_yen
EOF
cat >> tests/test_rounding.py <<'EOF'


class CeilKmTest(unittest.TestCase):
    def test_ceil_km(self):
        self.assertEqual(ceil_km(1), 1)
        self.assertEqual(ceil_km(100), 10)
        self.assertEqual(ceil_km(101), 11)
        self.assertEqual(ceil_km(239), 24)
EOF
commit "test: 距離の切り上げのテスト"

# ---- 58 ----
sub CHANGELOG.md <<'EOF'
# 変更履歴

=====
# 変更履歴

## 2.3.0

- 運賃の端数処理を見直し (10 円未満は四捨五入)
- 内訳の表示 (`--detail`)
- 経路探索の結果を覚えておく

EOF
sub README.md <<'EOF'
python3 -m fares 中央 西町 --round-trip
=====
python3 -m fares 中央 西町 --round-trip
python3 -m fares 川辺 空港 --detail
python3 -m fares --list
EOF
commit "docs: CHANGELOG と README を更新"

# ---- 59: v2.3 ----
sub fares/__init__.py <<'EOF'
__version__ = "2.2.0"
=====
__version__ = "2.3.0"
EOF
commit "release: 2.3.0"
git tag v2.3


find . -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true
