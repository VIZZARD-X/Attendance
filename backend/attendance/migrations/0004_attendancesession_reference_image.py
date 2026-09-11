# Generated migration for reference_image field

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('attendance', '0003_rename_student_name_studentprofile_student_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='attendancesession',
            name='reference_image',
            field=models.ImageField(blank=True, null=True, upload_to='session_references/%Y/%m/%d/'),
        ),
    ]
