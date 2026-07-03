-- Samikshya Baniya
-- Week 3 Assignment
-- File 1: week3_reliability.sql


-- Q1: Add indexes to the trips table
-- Goal: compare query performance before and after adding indexes.

-- Query A before indexing: filter by driver_id
EXPLAIN ANALYZE
SELECT *
FROM trips
WHERE driver_id = 3;

-- Query B before indexing: filter by status
EXPLAIN ANALYZE
SELECT *
FROM trips
WHERE status = 'cancelled';

-- Query C before indexing: filter by driver_id and status
EXPLAIN ANALYZE
SELECT *
FROM trips
WHERE driver_id = 3
  AND status = 'completed';


CREATE INDEX IF NOT EXISTS idx_trips_driver_id
ON trips(driver_id);

CREATE INDEX IF NOT EXISTS idx_trips_driver_status
ON trips(driver_id, status);

-- Query A before: Seq Scan, execution time = 0.677 ms
-- Query A after: Bitmap Index Scan using idx_trips_driver_id, execution time = 0.258 ms

-- Query B before: Bitmap Index Scan using idx_trips_status, execution time = 6.619 ms
-- Query B after: Bitmap Index Scan using idx_trips_status, execution time = 0.470 ms

-- Query C before: Seq Scan, execution time = 0.617 ms
-- Query C after: Bitmap Index Scan using idx_trips_driver_status, execution time = 0.302 ms

CREATE OR REPLACE VIEW completed_trips_view AS
SELECT
    t.trip_id,
    d.name AS driver_name,
    p.name AS rider_name,
    pickup.city_name AS pickup_city,
    dropoff.city_name AS dropoff_city,
    t.fare_amount,
    t.distance_km,
    t.rating,
    pm.name AS payment_method,
    t.requested_at,
    t.completed_at
FROM trips t
JOIN drivers d
    ON t.driver_id = d.driver_id
JOIN passengers p
    ON t.passenger_id = p.passenger_id
JOIN locations pickup
    ON t.pickup_location_id = pickup.location_id
JOIN locations dropoff
    ON t.dropoff_location_id = dropoff.location_id
JOIN payment_methods pm
    ON t.payment_method_id = pm.payment_method_id
WHERE t.status = 'completed';

SELECT * FROM completed_trips_view LIMIT 5;
SELECT COUNT(*) FROM completed_trips_view;

-- Q3: Create driver_summary view

CREATE OR REPLACE VIEW driver_summary AS
SELECT
    d.name AS driver_name,
    COUNT(t.trip_id) AS total_trips,
    COUNT(t.trip_id) FILTER (WHERE t.status = 'completed') AS completed_trips,
    COUNT(t.trip_id) FILTER (WHERE t.status = 'cancelled') AS cancelled_trips,
    ROUND(
        COUNT(t.trip_id) FILTER (WHERE t.status = 'cancelled') * 100.0
        / NULLIF(COUNT(t.trip_id), 0),
        1
    ) AS cancellation_rate,
    ROUND(
        AVG(t.fare_amount) FILTER (WHERE t.status = 'completed'),
        2
    ) AS avg_fare,
    ROUND(
        AVG(t.rating) FILTER (WHERE t.status = 'completed'),
        1
    ) AS avg_rating
FROM drivers d
LEFT JOIN trips t
    ON d.driver_id = t.driver_id
GROUP BY d.name;

SELECT *
FROM driver_summary
ORDER BY completed_trips DESC;

-- Q4: Transaction with intentional failure

-- The 4th trip uses rating = 99, which is invalid for the rating column.
-- This causes the transaction to fail.
-- Because all inserts are inside one transaction, PostgreSQL rolls back everything.
-- Verification result: drivers = 0, trips = 0.

BEGIN;

INSERT INTO drivers (name)
VALUES ('Test Driver');

INSERT INTO trips (
    driver_id,
    passenger_id,
    pickup_location_id,
    dropoff_location_id,
    fare_amount,
    distance_km,
    status,
    requested_at,
    completed_at,
    rating,
    payment_method_id
)
VALUES
(
    (SELECT driver_id FROM drivers WHERE name = 'Test Driver'),
    1, 1, 2, 500.00, 5.5, 'completed',
    NOW(), NOW(), 4.5, 1
),
(
    (SELECT driver_id FROM drivers WHERE name = 'Test Driver'),
    1, 2, 3, 600.00, 6.5, 'completed',
    NOW(), NOW(), 4.0, 1
),
(
    (SELECT driver_id FROM drivers WHERE name = 'Test Driver'),
    1, 3, 4, 700.00, 7.5, 'completed',
    NOW(), NOW(), 5.0, 1
),
(
    (SELECT driver_id FROM drivers WHERE name = 'Test Driver'),
    1, 4, 5, 800.00, 8.5, 'completed',
    NOW(), NOW(), 99, 1
);

COMMIT;

-- Because rating = 99 violates the CHECK constraint,
-- PostgreSQL rejects the transaction.
-- Run ROLLBACK if DBeaver leaves the transaction open.

ROLLBACK;

SELECT
    'drivers' AS tbl,
    COUNT(*) AS test_driver_rows
FROM drivers
WHERE name = 'Test Driver'
UNION ALL
SELECT 'trips', COUNT(*)
FROM trips t
JOIN drivers d ON t.driver_id = d.driver_id
WHERE d.name = 'Test Driver';

-- The invalid rating value caused an error.
-- Because all inserts were inside one transaction, PostgreSQL rolled back everything.
-- Verification result: drivers = 0, trips = 0.

-- Q6: Running total fare per driver

SELECT
    t.trip_id,
    d.name AS driver_name,
    t.requested_at,
    t.fare_amount,
    SUM(t.fare_amount) OVER (
        PARTITION BY t.driver_id
        ORDER BY t.requested_at
    ) AS running_total_fare
FROM trips t
JOIN drivers d
    ON t.driver_id = d.driver_id
WHERE t.status = 'completed'
ORDER BY d.name, t.requested_at;