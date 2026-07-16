-- Drop existing tables first so the script can re-run cleanly
-- fact_trips must be dropped first — it references all the dimensions
DROP TABLE IF EXISTS fact_trips;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_time;
DROP TABLE IF EXISTS dim_driver;
DROP TABLE IF EXISTS dim_passenger;
DROP TABLE IF EXISTS dim_location;
DROP TABLE IF EXISTS dim_payment_method;
DROP TABLE IF EXISTS dim_promo_code;
DROP TABLE IF EXISTS dim_vehicle;

CREATE TABLE dim_date (
    date_key        INTEGER      PRIMARY KEY,
    full_date       DATE         NOT NULL UNIQUE,
    year            SMALLINT     NOT NULL,
    quarter         SMALLINT     NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    month           SMALLINT     NOT NULL CHECK (month BETWEEN 1 AND 12),
    month_name      VARCHAR(10)  NOT NULL,
    week_of_year    SMALLINT     NOT NULL,
    day_of_week     SMALLINT     NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
    day_name        VARCHAR(10)  NOT NULL,
    is_weekend      BOOLEAN      NOT NULL
);

CREATE TABLE dim_time (
    time_key        INTEGER      PRIMARY KEY,
    hour            SMALLINT     NOT NULL CHECK (hour BETWEEN 0 AND 23),
    minute_bucket   SMALLINT     NOT NULL CHECK (minute_bucket IN (0, 15, 30, 45)),
    time_label      VARCHAR(8)   NOT NULL,
    time_of_day     VARCHAR(12)  NOT NULL,
    is_rush_hour    BOOLEAN      NOT NULL
);

CREATE TABLE dim_driver (
    driver_key      SERIAL       PRIMARY KEY,
    driver_id       INTEGER      NOT NULL,
    name            VARCHAR(100) NOT NULL,
    status          VARCHAR(20)  NOT NULL,
    joined_at       TIMESTAMP,
    tenure_bucket   VARCHAR(20)
);

CREATE TABLE dim_passenger (
    passenger_key   SERIAL       PRIMARY KEY,
    passenger_id    INTEGER      NOT NULL,
    name            VARCHAR(100) NOT NULL,
    status          VARCHAR(20)  NOT NULL,
    cohort_month    VARCHAR(7),
    created_at      TIMESTAMP
);

CREATE TABLE dim_location (
    location_key    SERIAL       PRIMARY KEY,
    location_id     INTEGER      NOT NULL UNIQUE,
    city_name       VARCHAR(100) NOT NULL,
    state_province  VARCHAR(100),
    country         VARCHAR(100),
    region          VARCHAR(30),
    latitude        NUMERIC(9,6),
    longitude       NUMERIC(9,6)
);

CREATE TABLE dim_payment_method (
    payment_method_key  SERIAL      PRIMARY KEY,
    payment_method_id   INTEGER     UNIQUE,
    name                VARCHAR(30) NOT NULL,
    type                VARCHAR(20),
    is_active           BOOLEAN
);

CREATE TABLE dim_promo_code (
    promo_code_key  SERIAL       PRIMARY KEY,
    promo_code_id   INTEGER      UNIQUE,
    code            VARCHAR(30),
    discount_type   VARCHAR(10),
    discount_value  NUMERIC(8,2),
    is_active       BOOLEAN
);

-- TASK 1: dim_vehicle — vehicle dimension table (must come before fact_trips)
CREATE TABLE dim_vehicle (
    vehicle_key     SERIAL       PRIMARY KEY,
    vehicle_id      INTEGER      NOT NULL UNIQUE,
    plate_number    VARCHAR(20)  NOT NULL,
    make            VARCHAR(50),
    model           VARCHAR(50),
    year            SMALLINT,
    color           VARCHAR(30),
    category        VARCHAR(20),
    is_active       BOOLEAN
);

CREATE TABLE fact_trips (
    trip_key                SERIAL          PRIMARY KEY,
    source_trip_id          INTEGER         NOT NULL UNIQUE,
    date_key                INTEGER         NOT NULL REFERENCES dim_date(date_key),
    driver_key              INTEGER         NOT NULL REFERENCES dim_driver(driver_key),
    passenger_key           INTEGER         NOT NULL REFERENCES dim_passenger(passenger_key),
    pickup_location_key     INTEGER         NOT NULL REFERENCES dim_location(location_key),
    dropoff_location_key    INTEGER         NOT NULL REFERENCES dim_location(location_key),
    payment_method_key      INTEGER         REFERENCES dim_payment_method(payment_method_key),
    promo_code_key          INTEGER         REFERENCES dim_promo_code(promo_code_key),
    vehicle_key             INTEGER         REFERENCES dim_vehicle(vehicle_key),
    time_key                INTEGER         REFERENCES dim_time(time_key),
    base_fare               NUMERIC(10,2),
    tip_amount              NUMERIC(8,2)    NOT NULL DEFAULT 0.00,
    discount_amount         NUMERIC(8,2)    NOT NULL DEFAULT 0.00,
    fare_amount             NUMERIC(10,2),
    distance_km             NUMERIC(6,2),
    duration_minutes        NUMERIC(6,1),
    trip_count              SMALLINT        NOT NULL DEFAULT 1,
    driver_rating           NUMERIC(2,1),
    passenger_rating        NUMERIC(2,1),
    surge_multiplier        NUMERIC(4,2),
    requested_at            TIMESTAMP       NOT NULL
);

INSERT INTO dim_date (
    date_key, full_date, year, quarter, month,
    month_name, week_of_year, day_of_week, day_name, is_weekend
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INTEGER,
    d::DATE,
    EXTRACT(YEAR    FROM d)::SMALLINT,
    EXTRACT(QUARTER FROM d)::SMALLINT,
    EXTRACT(MONTH   FROM d)::SMALLINT,
    TRIM(TO_CHAR(d, 'Month')),
    EXTRACT(WEEK    FROM d)::SMALLINT,
    EXTRACT(DOW     FROM d)::SMALLINT,
    TRIM(TO_CHAR(d, 'Day')),
    EXTRACT(DOW FROM d) IN (0, 6)
FROM generate_series(
    '2023-01-01'::TIMESTAMP,
    '2026-12-31'::TIMESTAMP,
    '1 day'::INTERVAL
) AS d;

INSERT INTO dim_time (time_key, hour, minute_bucket, time_label, time_of_day, is_rush_hour)
SELECT
    (h * 100 + m)::INTEGER,
    h::SMALLINT,
    m::SMALLINT,
    LPAD(h::TEXT, 2, '0') || ':' || LPAD(m::TEXT, 2, '0'),
    CASE
        WHEN h BETWEEN  6 AND 11 THEN 'Morning'
        WHEN h BETWEEN 12 AND 16 THEN 'Afternoon'
        WHEN h BETWEEN 17 AND 20 THEN 'Evening'
        ELSE                          'Night'
    END,
    (h BETWEEN 7 AND 8) OR (h BETWEEN 17 AND 19)
FROM
    generate_series(0, 23) AS h,
    generate_series(0, 45, 15) AS m
ORDER BY h, m;