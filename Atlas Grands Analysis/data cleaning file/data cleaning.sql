---1. Day type mismatch check

SELECT 
    date,
    ((DATEDIFF(DAY, 0, date) + 1) % 7) + 1 AS weekday_num,   -- Sunday=1, Monday=2, …, Saturday=7
    day_type AS day_type_raw,
    CASE 
        WHEN ((DATEDIFF(DAY, 0, date) + 1) % 7) + 1 IN (5, 6) THEN 'Weekend'   -- Friday=6, Saturday=5
        ELSE 'Weekday'
    END AS expected_day_type
FROM dim_date
ORDER BY date;


select * from  dim_date
----2. Find all fact_aggregated_bookings rows where check_in_date is NOT present 

select * from fact_aggregated_bookings
where check_in_date is null



------3.Where rating is null 
SELECT booking_id, ratings_given
FROM fact_bookings
WHERE ratings_given is null;

select * from fact_bookings



---------------------------------------------------------------------------------------------------------------
-----Solving data discrepancy 

------------------------------------------------------------------------------------------------
----Solving Discepancy 
---1. Day type mismatch check

SELECT 
    date,
    ((DATEDIFF(DAY, 0, date) + 1) % 7) + 1 AS weekday_num,   -- Sunday=1, Monday=2, …, Saturday=7
    day_type AS day_type_raw,
    CASE 
        WHEN ((DATEDIFF(DAY, 0, date) + 1) % 7) + 1 IN (5, 6) THEN 'Weekend'   -- Friday=6, Saturday=5
        ELSE 'Weekday'
    END AS expected_day_type
FROM dim_date
ORDER BY date;


select * from  dim_date
----2. Find all fact_aggregated_bookings where the check_in_date column had null values 


select * from fact_aggregated_bookings
where check_in_date is null

-- Rebuild fact_aggregated_bookings
SELECT 
    fb.property_id,
    fb.check_in_date,
    fb.room_category,
    COUNT(CASE WHEN fb.booking_status = 'Checked Out' THEN fb.booking_id END) AS successful_bookings,
    SUM(fb.no_guests) AS capacity
INTO fact_aggregated_bookings_cleaned
FROM fact_bookings fb
WHERE fb.check_in_date IS NOT NULL   -- ensures no null values
GROUP BY fb.property_id, fb.check_in_date, fb.room_category;

select * from fact_aggregated_bookings_cleaned

------3.where rating is null in fact_booking cleaned 
-- Create cleaned table with replaced ratings and all other columns
SELECT 
    booking_id,
    property_id,
    booking_date,
    check_in_date,
    checkout_date,
    room_category,
    no_guests,
    booking_platform,
    ISNULL(CAST(ratings_given AS VARCHAR(10)), 'Not Rated') AS ratings_given,
    booking_status,
    revenue_generated,
    revenue_realized
INTO fact_bookings_cleaned
FROM fact_bookings;

select * from fact_bookings_cleaned

select * from fact_bookings