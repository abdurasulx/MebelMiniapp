import pymysql

# `mysqlclient` (C kengaytmasi) kompilyatsiya qilish uchun tizim kutubxonalari
# (libmysqlclient-dev/libmariadb-dev) va build vositalari kerak — turli VPS/
# hosting muhitlarida bu doim ham muvaffaqiyatli o'tavermaydi. `PyMySQL` esa
# sof Python bo'lgani uchun hech narsa kompilyatsiya qilinmaydi, lekin
# Django'ning standart `django.db.backends.mysql` motoriga `MySQLdb` moduli
# kerak bo'ladi — shu ikki qatorlik "aldash" (shim) PyMySQL'ni xuddi shu
# interfeys bilan taqdim etadi.
pymysql.install_as_MySQLdb()
# PyMySQL standart holatda o'zini eski "1.4.6" versiya deb ko'rsatadi
# (mysqlclient bilan moslik uchun tanlangan eski taxallus) — Django esa
# (6.0+) kamida "2.2.1" talab qiladi va aks holda ImproperlyConfigured
# xatosi bilan to'xtaydi, garchi PyMySQL'ning o'zi to'liq ishlaydigan
# bo'lsa ham. Shu yerda haqiqiy (Django talabiga mos) versiya sifatida
# e'lon qilamiz — bu standart, hujjatlashtirilgan PyMySQL+Django yechimi.
pymysql.version_info = (2, 2, 4, "final", 0)
