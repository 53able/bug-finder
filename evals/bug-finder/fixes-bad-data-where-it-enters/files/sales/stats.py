"""売上の集計。"""


def total_amount(records):
    return sum(int(r["amount"]) for r in records)


def largest_sale(records):
    return max(records, key=lambda r: r["amount"])


def by_store(records):
    totals = {}
    for r in records:
        totals[r["store"]] = totals.get(r["store"], 0) + int(r["amount"])
    return totals
