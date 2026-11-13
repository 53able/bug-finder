"""料金プランと請求額の計算。"""

from .config import load_json


def load_plans():
    return load_json("plans.json")


def get_plan(plan_key):
    plans = load_plans()
    if plan_key not in plans:
        raise KeyError("プランが見つかりません: %s" % plan_key)
    return plans[plan_key]


def charge_for(plan_key, seats):
    """月額の内訳を返す。含まれる席数を超えた分だけ追加席の料金がかかる。"""
    plan = get_plan(plan_key)
    extra_seats = max(0, seats - plan["included_seats"])
    extra = extra_seats * plan["per_seat"]
    return {
        "label": plan["label"],
        "base": plan["monthly"],
        "extra_seats": extra_seats,
        "extra": extra,
        "subtotal": plan["monthly"] + extra,
    }


def tax_for(subtotal, rate):
    """消費税。1 円未満は四捨五入する。"""
    return int(subtotal * rate + 0.5)
