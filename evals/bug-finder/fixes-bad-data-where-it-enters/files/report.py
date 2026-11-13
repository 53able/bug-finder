"""使い方: python3 report.py"""

from sales.loader import load_sales
from sales.ranking import top_sales
from sales.stats import by_store, largest_sale, total_amount

if __name__ == "__main__":
    records = load_sales("data/sales.csv")
    print("合計:", total_amount(records))
    print("店舗別:", by_store(records))
    print("最大の取引:", largest_sale(records)["id"])
    print("上位3件:")
    for r in top_sales(records):
        print(" ", r["id"], r["store"], r["amount"])
