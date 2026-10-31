from django.db import migrations, models


def drop_token_unique(apps, schema_editor):
    if schema_editor.connection.vendor != "microsoft":
        return
    table = "token_blacklist_blacklistedtoken"
    with schema_editor.connection.cursor() as cursor:
        constraints = schema_editor.connection.introspection.get_constraints(cursor, table)
        for name, info in constraints.items():
            if info["unique"] and info["columns"] == ["token_id"]:
                schema_editor.execute(
                    f"ALTER TABLE {schema_editor.quote_name(table)} "
                    f"DROP CONSTRAINT {schema_editor.quote_name(name)}"
                )


def restore_token_unique(apps, schema_editor):
    if schema_editor.connection.vendor == "microsoft":
        schema_editor.execute(
            "ALTER TABLE [token_blacklist_blacklistedtoken] "
            "ADD CONSTRAINT [hotel_jwt_token_id_uniq] UNIQUE ([token_id])"
        )


class Migration(migrations.Migration):
    dependencies = [
        ("token_blacklist", "0007_auto_20171017_2214"),
    ]

    operations = [
        migrations.RunPython(drop_token_unique, restore_token_unique),
        migrations.AlterField(
            model_name="blacklistedtoken",
            name="id",
            field=models.BigAutoField(
                auto_created=True, primary_key=True, serialize=False, verbose_name="ID"
            ),
        ),
        migrations.AlterField(
            model_name="outstandingtoken",
            name="id",
            field=models.BigAutoField(
                auto_created=True, primary_key=True, serialize=False, verbose_name="ID"
            ),
        ),
        migrations.RunPython(restore_token_unique, drop_token_unique),
    ]
