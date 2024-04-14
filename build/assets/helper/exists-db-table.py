import sys
import time
import sqlalchemy

try:
    db_uri = sys.argv[1]
    db_table = sys.argv[2]

    engine = sqlalchemy.engine.create_engine(db_uri)
    with engine.connect() as db:
        exists = engine.has_table(db_table)

        if exists:
            sys.exit(0)
        else:
            sys.exit(1)

except Exception:
    print(traceback.format_exc())
    exit(2)


