from django.db import connection, migrations


def drop_column_if_exists(apps, schema_editor):
    with connection.cursor() as cursor:
        if connection.vendor == "sqlite":
            try:
                cursor.execute("PRAGMA table_info(enrollments)")
                columns = [row[1] for row in cursor.fetchall()]
                if "status" in columns:
                    cursor.execute("ALTER TABLE enrollments DROP COLUMN status;")
            except Exception:
                pass
        else:
            try:
                cursor.execute("ALTER TABLE enrollments DROP COLUMN IF EXISTS status;")
            except Exception:
                pass


class Migration(migrations.Migration):

    dependencies = [
        ("attendance", "0010_remove_studentprofile_roll_no_and_more"),
    ]

    operations = [
        migrations.RunPython(drop_column_if_exists, migrations.RunPython.noop),
    ]
