These migrations are copied from djangorestframework-simplejwt 5.5.1,
copyright David Sanders and contributors, under the MIT license (LICENSE.txt).

Only 0008 is changed: it temporarily removes the SQL Server UNIQUE constraint
on BlacklistedToken.token_id before the parent ID conversion, then restores it.
This preserves schema and migration state without modifying installed packages,
disabling the blacklist, faking migrations, or dropping application data.

Keep this migration snapshot in sync when deliberately upgrading Simple JWT.
