{# 月次の請求のお知らせ #}
{{ customer }} ご担当者様

{{ greeting }}
{{ period_label }}分のご請求額をお知らせします。

  プラン: {{ plan_label }} ({{ seats }} 席)
  ご請求額: {{ total }}
  お支払い期限: {{ due }}

{{ footer_text | wrap(30) }}

お問い合わせ先:
{{ reply_to | indent(2) }}

{{ sender_name }}
