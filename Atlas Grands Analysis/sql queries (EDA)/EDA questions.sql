--1. Total revenue generated for the latest available month in data
SELECT 
    h.property_id,
    SUM(f.revenue_realized) AS total_revenue
FROM fact_bookings_cleaned f
JOIN dim_hotels h 
    ON f.property_id = h.property_id
JOIN dim_date_cleaned d 
    ON f.check_in_date = d.date
WHERE f.booking_status = 'Checked Out'
  AND d.mmm_yy = (
        SELECT MAX(d2.mmm_yy)
        FROM fact_bookings f2
        JOIN dim_date d2 ON f2.check_in_date = d2.date
        WHERE f2.booking_status = 'Checked Out'
    )
GROUP BY h.property_id
ORDER BY total_revenue DESC;

----2. Average occupancy % (weekdays vs weekends)
SELECT 
    d.day_type,  -- 'Weekday' or 'Weekend'
    AVG(CAST(fab.successful_bookings AS FLOAT) / NULLIF(fab.capacity,0)) * 100 AS avg_occupancy_pct
FROM fact_aggregated_bookings_cleaned fab
JOIN dim_date_cleaned d ON fab.check_in_date = d.date
GROUP BY d.day_type;

---3.Room categories (RT1–RT4) highest booking share
SELECT 
    fab.room_category,
    SUM(fab.successful_bookings) AS total_bookings,
    (SUM(fab.successful_bookings) * 100.0 / 
     SUM(SUM(fab.successful_bookings)) OVER()) AS booking_share_pct
FROM fact_aggregated_bookings_cleaned fab
GROUP BY fab.room_category
ORDER BY booking_share_pct DESC;

---4 ADR (Average Daily Rate) by property category

SELECT 
    h.category AS property_category,
    CAST(SUM(CAST(fb.revenue_realized AS BIGINT)) AS DECIMAL(18,2)) 
        / NULLIF(SUM(CAST(fab.successful_bookings AS BIGINT)),0) AS ADR
FROM fact_bookings_cleaned fb
JOIN dim_hotels h ON fb.property_id = h.property_id
JOIN fact_aggregated_bookings_cleaned fab 
     ON fb.property_id = fab.property_id 
    AND fb.check_in_date = fab.check_in_date
GROUP BY h.category;

---5.Bookings per platform (OTA vs direct vs walk-in)
SELECT 
    fb.booking_platform,
    COUNT(*) AS total_bookings
FROM fact_bookings_cleaned fb
GROUP BY fb.booking_platform
ORDER BY total_bookings DESC;

---6.Average rating per hotel and room type

SELECT 
    h.property_name,
    fb.room_category,
    AVG(CAST(fb.ratings_given AS DECIMAL(10,2))) AS avg_rating
FROM fact_bookings_cleaned fb
JOIN dim_hotels h ON fb.property_id = h.property_id
GROUP BY h.property_name, fb.room_category
ORDER BY h.property_name, fb.room_category DESC;


SELECT 
    h.property_name,
    fb.room_category,
    AVG(TRY_CAST(fb.ratings_given AS DECIMAL(10,2))) AS avg_rating
FROM fact_bookings_cleaned fb
JOIN dim_hotels h ON fb.property_id = h.property_id
WHERE TRY_CAST(fb.ratings_given AS DECIMAL(10,2)) IS NOT NULL
GROUP BY h.property_name, fb.room_category
ORDER BY h.property_name, fb.room_category DESC;


---7. City with highest RevPAR
SELECT 
    h.city,
    CAST(SUM(CAST(fb.revenue_realized AS BIGINT)) AS DECIMAL(18,2)) 
        / NULLIF(SUM(CAST(fab.capacity AS BIGINT)),0) AS RevPAR
FROM fact_bookings_cleaned fb
JOIN dim_hotels h ON fb.property_id = h.property_id
JOIN fact_aggregated_bookings_cleaned fab 
     ON fb.property_id = fab.property_id 
    AND fb.check_in_date = fab.check_in_date
GROUP BY h.city
ORDER BY RevPAR DESC;


---8. Cancellation % overall and by room category
-- Overall
SELECT 
    (SUM(CASE WHEN fb.booking_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0) 
    / COUNT(*) AS cancellation_pct_overall
FROM fact_bookings_cleaned fb;

-- By room category
SELECT 
    fb.room_category,
    (SUM(CASE WHEN fb.booking_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0) 
    / COUNT(*) AS cancellation_pct
FROM fact_bookings_cleaned fb
GROUP BY fb.room_category;

----9.No-show bookings and revenue lost

SELECT 
    COUNT(*) AS no_show_bookings,
    SUM(fb.revenue_realized) AS revenue_lost
FROM fact_bookings_cleaned fb
WHERE fb.booking_status = 'No Show';

---10. WoW change in Revenue, Occupancy, ADR, RevPAR

WITH weekly_metrics AS (
    SELECT 
        d.week_no,
        SUM(fb.revenue_realized) AS total_revenue,
        SUM(fab.successful_bookings) AS total_bookings,
        SUM(fab.capacity) AS total_capacity,
        (SUM(fb.revenue_realized) / NULLIF(SUM(fab.successful_bookings),0)) AS ADR,
        (SUM(fb.revenue_realized) / NULLIF(SUM(fab.capacity),0)) AS RevPAR
    FROM fact_bookings_cleaned fb
    JOIN dim_date d ON fb.check_in_date = d.date
    JOIN fact_aggregated_bookings_cleaned fab 
        ON fb.property_id = fab.property_id 
       AND fb.check_in_date = fab.check_in_date
    GROUP BY d.week_no
)
SELECT 
    week_no,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY week_no) AS prev_revenue,
    (total_revenue - LAG(total_revenue) OVER (ORDER BY week_no)) 
       * 100.0 / NULLIF(LAG(total_revenue) OVER (ORDER BY week_no),0) AS revenue_wow_change,
    
    (CAST(total_bookings AS FLOAT) / NULLIF(total_capacity,0)) AS occupancy,
    (CAST(total_bookings AS FLOAT) / NULLIF(total_capacity,0)) -
       LAG(CAST(total_bookings AS FLOAT) / NULLIF(total_capacity,0)) 
       OVER (ORDER BY week_no) AS occupancy_wow_change,

    ADR,
    ADR - LAG(ADR) OVER (ORDER BY week_no) AS adr_wow_change,

    RevPAR,
    RevPAR - LAG(RevPAR) OVER (ORDER BY week_no) AS revpar_wow_change
FROM weekly_metrics;

---------------------------------------------------------------------------------------------------------

---1. Why did occupancy % drop in some properties despite high capacity?
SELECT 
    h.property_name,
    h.city,
    SUM(fab.successful_bookings) AS total_bookings,
    SUM(fab.capacity) AS total_capacity,
    (SUM(fab.successful_bookings) * 100.0 / NULLIF(SUM(fab.capacity),0)) AS occupancy_pct
FROM fact_aggregated_bookings_cleaned fab
JOIN dim_hotels h ON fab.property_id = h.property_id
GROUP BY h.property_name, h.city
ORDER BY occupancy_pct ASC;

---2. Which booking platforms have the highest cancellation rates and why?

SELECT 
    fb.booking_platform,
    COUNT(*) AS total_bookings,
    SUM(CASE WHEN fb.booking_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_bookings,
    (SUM(CASE WHEN fb.booking_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) AS cancellation_rate_pct
FROM fact_bookings_cleaned fb
GROUP BY fb.booking_platform
ORDER BY cancellation_rate_pct DESC;

---3.Why is revenue realization % lower in some hotels?
SELECT 
    h.property_name,
    h.city,
    SUM(fb.revenue_generated) AS revenue_generated,
    SUM(fb.revenue_realized) AS revenue_realized,
    (SUM(fb.revenue_realized) * 100.0 / NULLIF(SUM(fb.revenue_generated),0)) AS revenue_realization_pct
FROM fact_bookings_cleaned fb
JOIN dim_hotels h ON fb.property_id = h.property_id
GROUP BY h.property_name, h.city
ORDER BY revenue_realization_pct ASC;

---4.Why do weekend bookings outperform weekdays in some cities but not others?
SELECT 
    h.city,
    d.day_type,
    COUNT(fb.booking_id) AS total_bookings
FROM fact_bookings_cleaned fb
JOIN dim_hotels h ON fb.property_id = h.property_id
JOIN dim_date_cleaned d ON fb.check_in_date = d.date
GROUP BY h.city, d.day_type
ORDER BY h.city, total_bookings DESC;

---5.Why are premium rooms under-booked compared to standard rooms?
SELECT 
    fab.room_category,
    SUM(fab.successful_bookings) AS total_bookings,
    SUM(fab.capacity) AS total_capacity,
    (SUM(fab.successful_bookings) * 100.0 / NULLIF(SUM(fab.capacity),0)) AS occupancy_pct
FROM fact_aggregated_bookings_cleaned fab
GROUP BY fab.room_category
ORDER BY occupancy_pct ASC;

---6. Why are ratings lower in some hotels — linked to property category, room class, or location?

SELECT 
    h.property_name,
    h.category AS property_category,
    h.city,
    fb.room_category,
    AVG(TRY_CAST(fb.ratings_given AS DECIMAL(10,2))) AS avg_rating
FROM fact_bookings_cleaned fb
JOIN dim_hotels h ON fb.property_id = h.property_id
WHERE TRY_CAST(fb.ratings_given AS DECIMAL(10,2)) IS NOT NULL
GROUP BY h.property_name, h.category, h.city, fb.room_category
ORDER BY avg_rating ASC;

---7.Why did RevPAR decline WoW despite stable occupancy?
--(RevPAR = Revenue Realized ÷ Capacity)

WITH weekly_metrics AS (
    SELECT 
        d.week_no,
        h.property_name,
        SUM(fb.revenue_realized_corrected) / NULLIF(SUM(fab.capacity),0) AS RevPAR,
        SUM(fab.successful_bookings) * 1.0 / NULLIF(SUM(fab.capacity),0) AS Occupancy
    FROM fact_bookings_cleaned fb
    JOIN fact_aggregated_bookings_cleaned fab ON fb.property_id = fab.property_id 
        AND fb.check_in_date = fab.check_in_date
    JOIN dim_date d ON fb.check_in_date = d.date
    JOIN dim_hotels h ON fb.property_id = h.property_id
    GROUP BY d.week_no, h.property_name
)
SELECT 
    property_name,
    week_no,
    RevPAR,
    LAG(RevPAR) OVER(PARTITION BY property_name ORDER BY week_no) AS prev_RevPAR,
    Occupancy,
    LAG(Occupancy) OVER(PARTITION BY property_name ORDER BY week_no) AS prev_occupancy
FROM weekly_metrics;


---8.Which booking platforms contribute the highest share of bookings for each hotel?
SELECT 
    h.property_name,
    SUM(CASE WHEN fb.booking_platform = 'others' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS other_pct,
    SUM(CASE WHEN fb.booking_platform = 'direct online' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS direct_online_pct,
	SUM(CASE WHEN fb.booking_platform = 'journey' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS journey_pct,
	SUM(CASE WHEN fb.booking_platform = 'direct offline' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS direct_offline_pct,
	SUM(CASE WHEN fb.booking_platform = 'tripster' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS tripster_pct,
	SUM(CASE WHEN fb.booking_platform = 'logtrip' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS logtrip_pct,
	SUM(CASE WHEN fb.booking_platform = 'makeyourtrip' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS makeyourtrip_pct
FROM fact_bookings_cleaned fb
JOIN dim_hotels h ON fb.property_id = h.property_id
GROUP BY h.property_name

-- 9. Why do some cities show high guest count per booking compared to others?
SELECT 
    h.city,
    ROUND(AVG(fb.no_guests), 2) AS avg_guests_per_booking
FROM fact_bookings_cleaned fb
JOIN dim_hotels h ON fb.property_id = h.property_id
GROUP BY h.city
ORDER BY avg_guests_per_booking DESC;

---10.Why does ADR fluctuate more in one city compared to another?
SELECT 
    h.city,
    d.week_no,
    SUM(fb.revenue_realized_corrected) * 1.0 / NULLIF(SUM(fab.successful_bookings),0) AS ADR
FROM fact_bookings_cleaned fb
JOIN fact_aggregated_bookings_cleaned fab ON fb.property_id = fab.property_id 
    AND fb.check_in_date = fab.check_in_date
JOIN dim_hotels h ON fb.property_id = h.property_id
JOIN dim_date_cleaned d ON fb.check_in_date = d.date
GROUP BY h.city, d.week_no
ORDER BY  d.week_no;

-----------------------------------------------------------------------------


