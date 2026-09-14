import pymysql

# `mysqlclient` (C kengaytmasi) kompilyatsiya qilish uchun tizim kutubxonalari
# (libmysqlclient-dev/libmariadb-dev) va build vositalari kerak — turli VPS/
# hosting muhitlarida bu doim ham muvaffaqiyatli o'tavermaydi. `PyMySQL` esa
# sof Python bo'lgani uchun hech narsa kompilyatsiya qilinmaydi, lekin
# Django'ning standart `django.db.backends.mysql` motoriga `MySQLdb` moduli
# kerak bo'ladi — shu ikki qatorlik "aldash" (shim) PyMySQL'ni xuddi shu
# interfeys bilan taqdim etadi.
pymysql.install_as_MySQLdb()
