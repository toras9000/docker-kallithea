import sys
import time
import sqlalchemy

db_uri = sys.argv[1]

print(f"Connect to '{db_uri}'")
engine = sqlalchemy.engine.create_engine(db_uri)
while True:
    try:
        with engine.connect() as db:
            print("... success")
            break

    except:
        print("Retry the database connection after 5 seconds.")
        time.sleep(5)
