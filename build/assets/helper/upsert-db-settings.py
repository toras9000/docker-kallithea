import sys
import time
import sqlalchemy
from sqlalchemy import text as sql_text

try:
    db_uri = sys.argv[1]
    setting_key = sys.argv[2]
    setting_value = sys.argv[3]
    setting_type = sys.argv[4]

    engine = sqlalchemy.engine.create_engine(db_uri)
    with engine.connect() as db:
        setting_id = db.scalar(sql_text("select app_settings_id from settings where app_settings_name = :key"), { "key": setting_key, })
        if setting_id is None:
            sql = sql_text("insert into settings(app_settings_name, app_settings_value, app_settings_type) values (:key, :value, :type)")
            params = { "key": setting_key, "value": setting_value, "type": setting_type, }
        else:
            sql = sql_text("update settings set app_settings_value = :value where app_settings_name = :key")
            params = { "key": setting_key, "value": setting_value, }
        db.execute(sql, params)

except Exception:
    print(traceback.format_exc())
    exit(1)

