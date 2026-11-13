"""金額と日付の表示用の整形。"""

import calendar
import datetime


def yen(amount, unit="円"):
    return "{:,}{}".format(amount, unit)


def period_label(period):
    """'2025-10' を '2025年10月' にする。"""
    year, month = period.split("-")
    return "%s年%d月" % (year, int(month))


def due_date(period, days):
    """請求月の末日から days 日後の日付を '2025年11月30日' の形で返す。"""
    year, month = (int(x) for x in period.split("-"))
    last_day = datetime.date(year, month, calendar.monthrange(year, month)[1])
    due = last_day + datetime.timedelta(days=days)
    return "%d年%d月%d日" % (due.year, due.month, due.day)
