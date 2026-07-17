from Week5.submission.samikshya_baniya_submission.quality import run_quality_checks, DataQualityError

# Fake a row with a negative fare, like your real transform.py would produce
fake_rows = [{
    "source_trip_id": 99999,
    "date_key": 20260717,
    "driver_key": 1,
    "passenger_key": 1,
    "pickup_location_key": 1,
    "dropoff_location_key": 1,
    "payment_method_key": 1,
    "promo_code_key": None,
    "base_fare": 100,
    "tip_amount": 0,
    "discount_amount": 0,
    "fare_amount": -999,   # <-- the bad value we're testing
    "distance_km": 5,
    "status": "completed",
    "duration_minutes": 10,
    "driver_rating": 5,
    "passenger_rating": 5,
    "surge_multiplier": 1,
    "requested_at": "2026-07-17",
}]

run_quality_checks(fake_rows)