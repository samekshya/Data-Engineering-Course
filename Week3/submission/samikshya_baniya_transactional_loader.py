import psycopg2
import logging
import os

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s  %(message)s"
)
logger = logging.getLogger(__name__)

DB_CONFIG = dict(
    host=os.getenv("DB_HOST"),
    port=os.getenv("DB_PORT"),
    dbname=os.getenv("DB_NAME"),
    user=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD")
)

INSERT_SQL = """
    INSERT INTO trips (
        driver_id, passenger_id,
        pickup_location_id, dropoff_location_id,
        fare_amount, distance_km, status,
        requested_at, completed_at, rating, payment_method_id
    ) VALUES (
        %(driver_id)s, %(passenger_id)s,
        %(pickup_location_id)s, %(dropoff_location_id)s,
        %(fare_amount)s, %(distance_km)s, %(status)s,
        %(requested_at)s, %(completed_at)s,
        %(rating)s, %(payment_method_id)s
    )
"""


def load_batch(conn, rows: list) -> int:
    conn.autocommit = False

    try:
        with conn.cursor() as cur:
            for row_number, row in enumerate(rows, start=1):
                try:
                    cur.execute(INSERT_SQL, row)
                except Exception as e:
                    logger.error(f"Failed on row {row_number}: {row}")
                    logger.error(f"Error: {e}")
                    raise

        conn.commit()
        return len(rows)

    except Exception:
        conn.rollback()
        logger.info("Transaction rolled back. No rows from this batch were inserted.")
        raise


def get_test_batches():
    base = dict(
        driver_id=1,
        passenger_id=1,
        pickup_location_id=1,
        dropoff_location_id=2,
        fare_amount=250.00,
        distance_km=8.5,
        status="completed",
        requested_at="2025-01-15 09:00:00",
        completed_at="2025-01-15 09:35:00",
        rating=4.5,
        payment_method_id=1
    )

    good_batch = [{**base, "fare_amount": 100 * (i + 1)} for i in range(5)]

    bad_batch = []
    for i in range(5):
        row = {**base, "fare_amount": 100 * (i + 1)}
        if i == 2:
            row["rating"] = 99
        bad_batch.append(row)

    return good_batch, bad_batch


def main():
    conn = psycopg2.connect(**DB_CONFIG)

    try:
        good_batch, bad_batch = get_test_batches()

        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM trips")
            count_before = cur.fetchone()[0]

        logger.info(f"Trips before any load: {count_before:,}")

        logger.info("--- Test 1: loading good batch ---")
        try:
            loaded = load_batch(conn, good_batch)
            logger.info(f"Test 1 passed: {loaded} rows loaded")
        except Exception as e:
            logger.error(f"Test 1 failed unexpectedly: {e}")

        logger.info("--- Test 2: loading bad batch ---")
        try:
            loaded = load_batch(conn, bad_batch)
            logger.warning(f"Test 2 loaded {loaded} rows unexpectedly")
        except Exception:
            logger.info("Test 2 passed: exception raised and batch rolled back")

        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM trips")
            count_after = cur.fetchone()[0]

        logger.info(f"Trips after both tests: {count_after:,}")
        logger.info(f"Net rows added: {count_after - count_before}")

    finally:
        conn.close()


if __name__ == "__main__":
    main()