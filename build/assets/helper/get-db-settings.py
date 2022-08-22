import sys
import time
import sqlalchemy
from sqlalchemy import text as sql_text

try:
    db_uri = sys.argv[1]
    setting_key = sys.argv[2]

    engine = sqlalchemy.engine.create_engine(db_uri)
    with engine.connect() as db:
        value = db.scalar(sql_text("select app_settings_value from settings where app_settings_name = :key"), { "key": setting_key, })
        if value is None:
            print("((None))")
        else:
            print(value)

except Exception:
    print(traceback.format_exc())
    exit(1)
