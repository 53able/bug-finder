"""請求書のテキストを作る。"""

from .catalog import charge_for, tax_for
from .formatting import due_date, period_label, yen


def build_invoice(tenant):
    """請求書に載せる金額と文言をまとめた辞書を返す。"""
    settings = tenant.settings
    billing = settings["billing"]
    charge = charge_for(tenant.plan, tenant.seats)
    tax = tax_for(charge["subtotal"], billing["tax_rate"])
    unit = billing["currency"]
    return {
        "period": period_label(settings["period"]),
        "charge": charge,
        "tax": tax,
        "total": charge["subtotal"] + tax,
        "unit": unit,
        "due": due_date(settings["period"], billing["due_days"]),
        "note": billing["note"],
        "footer": settings["mail"]["footer_text"],
        "contact": settings["mail"]["reply_to"],
    }


def render_invoice_text(tenant):
    data = build_invoice(tenant)
    charge = data["charge"]
    unit = data["unit"]
    lines = [
        "請求書 (%s分)" % data["period"],
        "宛先: %s 御中" % tenant.name,
        "",
        "プラン: %s (%d 席)" % (charge["label"], tenant.seats),
        "  基本料金      %s" % yen(charge["base"], unit),
    ]
    if charge["extra_seats"]:
        lines.append(
            "  追加席 %d 席   %s" % (charge["extra_seats"], yen(charge["extra"], unit))
        )
    lines += [
        "  小計          %s" % yen(charge["subtotal"], unit),
        "  消費税        %s" % yen(data["tax"], unit),
        "  合計          %s" % yen(data["total"], unit),
        "",
        "お支払い期限: %s" % data["due"],
        "備考: %s" % data["note"],
        "",
        "%s" % data["footer"],
        "お問い合わせ: %s" % data["contact"],
    ]
    return "\n".join(lines)
