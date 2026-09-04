from django.contrib import admin

from .models import AttendanceEditLog, AttendanceRecord, Workplace

admin.site.register(Workplace)
admin.site.register(AttendanceRecord)
admin.site.register(AttendanceEditLog)
