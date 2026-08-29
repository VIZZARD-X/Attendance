from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ("attendance", "0010_remove_studentprofile_roll_no_and_more"),
    ]

    operations = [
        migrations.RunSQL(
            sql="ALTER TABLE enrollments DROP COLUMN IF EXISTS status;",
            reverse_sql="ALTER TABLE enrollments ADD COLUMN status varchar(20);",
        ),
    ]
