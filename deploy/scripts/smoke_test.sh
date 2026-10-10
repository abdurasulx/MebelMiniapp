#!/usr/bin/env bash
# Yangi server ishga tushgach tezkor tekshiruv:  ./smoke_test.sh vidamarket.uz
set -u
D="${1:-vidamarket.uz}"
ok() { printf "  %-46s %s\n" "$1" "$2"; }
code() { curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$@"; }

ok "web  https://$D/"                  "$(code https://$D/)"
ok "web  https://admin.$D/"            "$(code https://admin.$D/)"
ok "web  https://firma.$D/"            "$(code https://firma.$D/)"
ok "api  /api/v1/categories/"          "$(code https://api.$D/api/v1/categories/)"
ok "api  /api/v1/showcase/products/"   "$(code https://api.$D/api/v1/showcase/products/)"
ok "api  OTP so'rovi (400 kutiladi)"   "$(code -X POST -H 'Content-Type: application/json' -d '{}' https://api.$D/api/v1/auth/otp/request/)"
ok "api  app-version check"            "$(code https://api.$D/api/v1/app-version/check/ )"
ok "http -> https redirect"            "$(code http://$D/)"
echo "Kutilgan: 200 (web/api), 400 (OTP), 301 (redirect). WebSocket va rasm qidiruvini qo'lda tekshiring."
