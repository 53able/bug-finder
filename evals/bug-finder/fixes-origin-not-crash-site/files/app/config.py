"""データファイルの読み込みと、設定のマージ。"""

import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"


def load_json(name):
    with open(DATA_DIR / name, encoding="utf-8") as f:
        return json.load(f)


def merge_settings(base, override):
    """base に override を重ねた新しい辞書を返す。

    入れ子の辞書は、キーごとに再帰して重ねる。base と override は変更しない。
    """
    merged = copy.deepcopy(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = merge_settings(merged[key], value)
        else:
            merged[key] = copy.deepcopy(value)
    return merged
