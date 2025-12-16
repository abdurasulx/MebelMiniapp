from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('main', '0008_remove_basketitem_image_remove_basketitem_material_and_more'),
    ]

    operations = [
        migrations.RunSQL(
            # Forward SQL - add columns
            sql="""
                ALTER TABLE auth_user ADD COLUMN tg_id BIGINT NULL;
                ALTER TABLE auth_user ADD COLUMN phone VARCHAR(20) NULL;
                CREATE UNIQUE INDEX auth_user_tg_id_unique ON auth_user(tg_id) WHERE tg_id IS NOT NULL;
            """,
            # Reverse SQL - remove columns  
            reverse_sql="""
                DROP INDEX IF EXISTS auth_user_tg_id_unique;
                ALTER TABLE auth_user DROP COLUMN tg_id;
                ALTER TABLE auth_user DROP COLUMN phone;
            """
        ),
    ]
