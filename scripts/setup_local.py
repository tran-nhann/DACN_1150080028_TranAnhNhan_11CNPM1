"""Create only the isolated development database and a private local .env."""

import secrets
import sys
from pathlib import Path

import pyodbc
from dotenv import dotenv_values

sys.stdout.reconfigure(encoding="utf-8")

root = Path(__file__).resolve().parent.parent
env_path = root / "backend" / ".env"
if not env_path.exists():
    template = (root / "backend" / ".env.example").read_text(encoding="utf-8")
    template = template.replace(
        "replace-with-a-random-secret", secrets.token_urlsafe(64)
    )
    template = template.replace(
        "replace-with-a-local-demo-password", "Aster!" + secrets.token_urlsafe(16)
    )
    env_path.write_text(template, encoding="utf-8")
env = dotenv_values(env_path)
if env.get("DB_NAME") != "HotelManagementDev":
    raise SystemExit("Script này chỉ được phép tạo HotelManagementDev.")
driver = env.get("DB_DRIVER", "ODBC Driver 18 for SQL Server")
server = env.get("DB_HOST", r"lpc:.\SQLEXPRESS")
connection_string = f"DRIVER={{{driver}}};SERVER={server};DATABASE=master;"
if env.get("DB_USER"):
    connection_string += f"UID={env['DB_USER']};PWD={env['DB_PASSWORD']};"
else:
    connection_string += "Trusted_Connection=yes;"
connection_string += env.get("DB_EXTRA_PARAMS", "Encrypt=yes;TrustServerCertificate=no")
with pyodbc.connect(connection_string, autocommit=True, timeout=5) as db:
    db.execute(
        "IF DB_ID(N'HotelManagementDev') IS NULL CREATE DATABASE [HotelManagementDev]"
    )
print("SQL Server: HotelManagementDev sẵn sàng. Cấu hình riêng nằm trong backend/.env.")
