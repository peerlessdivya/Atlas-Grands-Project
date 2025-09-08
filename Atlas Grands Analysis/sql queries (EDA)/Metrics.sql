---Total Revenue 
select sum(revenue_realized) as total_revenue
from fact_bookings_cleaned

---Total Bookings 

SELECT COUNT(DISTINCT booking_id) as total_booking
FROM fact_bookings_cleaned;


----Total Capacity 

SELECT SUM(capacity) AS Total_Capacity
FROM fact_aggregated_bookings_cleaned;

--Total Capacity hotel wise 
select sum(capacity) as total_capacity,property_id
from fact_aggregated_bookings_cleaned
group by property_id
order by total_capacity


---Total Successfull booking

SELECT SUM(successful_bookings) AS Total_Successful_Bookings
FROM fact_aggregated_bookings_cleaned;


---Total Successfull booking hotelwise 
select sum(successful_bookings) as [total successful booking], property_id
from fact_aggregated_bookings_cleaned
group by property_id
order by [total successful booking]

---Occupancy %

SELECT 
    (CAST(SUM(successful_bookings) AS FLOAT) / NULLIF(SUM(capacity),0)) * 100 AS Occupancy_Percentage
FROM fact_aggregated_bookings_cleaned;


---Occupancy % by hotelwise
SELECT 
    property_id,
    SUM(capacity) AS total_capacity,
    SUM(successful_bookings) AS total_successful_bookings,
    (SUM(successful_bookings) * 100.0 / NULLIF(SUM(capacity),0)) AS occupancy_percent
FROM fact_aggregated_bookings_cleaned
GROUP BY property_id
ORDER BY occupancy_percent DESC;

----Average Rating 
SELECT AVG(TRY_CAST(ratings_given AS FLOAT)) AS avg_rating
FROM fact_bookings_cleaned
WHERE ratings_given <> 'Not Rated';


---Total Cancelled booking 

SELECT COUNT(*) AS total_cancelled
FROM fact_bookings_cleaned
WHERE booking_status = 'cancelled';

---Cancellation % 
SELECT 
    (SUM(CASE WHEN booking_status = 'cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*))
	AS cancellation_percent
FROM fact_bookings_cleaned;

---Total Checked out
SELECT COUNT(*) AS total_checked_out
FROM fact_bookings_cleaned
WHERE booking_status = 'checked Out';

---Total no show booking 
SELECT COUNT(*) AS total_no_show
FROM fact_bookings_cleaned
WHERE booking_status = 'no show';

---No Show Rate %
SELECT 
    (SUM(CASE WHEN booking_status = 'no show' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) 
	AS no_show_rate_percent
FROM fact_bookings_cleaned;

---Booking % by Platform

SELECT booking_platform,
       (COUNT(*) * 100.0 / (SELECT COUNT(*) FROM fact_bookings)) AS booking_percent
FROM fact_bookings_cleaned
GROUP BY booking_platform;

---Booking % by Room Class

SELECT r.room_class,
       (COUNT(*) * 100.0 / (SELECT COUNT(*) FROM fact_bookings)) AS booking_percent
FROM fact_bookings_cleaned b
JOIN dim_rooms r ON b.room_category = r.room_id
GROUP BY r.room_class;

---ADR – overall Average Daily Rate

SELECT 
    SUM(revenue_realized) * 1.0 / NULLIF(COUNT
	(CASE 
		WHEN booking_status = 'Checked Out'
			THEN booking_id END), 0) AS ADR
FROM fact_bookings;


---ADR per day 
SELECT 
    fb.check_in_date,
    SUM(fb.revenue_realized) * 1.0 / NULLIF(COUNT
	(CASE
		WHEN fb.booking_status = 'Checked Out'
			THEN fb.booking_id END), 0) AS ADR
FROM fact_bookings fb
GROUP BY fb.check_in_date
ORDER BY fb.check_in_date;

---ADR per hotel 

SELECT 
    h.property_name,
    SUM(fb.revenue_realized) * 1.0 / 
    NULLIF(COUNT(CASE WHEN fb.booking_status = 'Checked Out' THEN fb.booking_id END), 0) AS ADR
FROM fact_bookings fb
JOIN dim_hotels h 
    ON fb.property_id = h.property_id
GROUP BY h.property_name;

select * from dim_hotels

---RevPAR – overall Revenue per Available Room
SELECT 
    SUM(fb.revenue_realized) * 1.0 / NULLIF(SUM(fa.capacity), 0) AS RevPAR
FROM fact_bookings fb
JOIN fact_aggregated_bookings fa
    ON fb.property_id = fa.property_id
   AND fb.check_in_date = fa.check_in_date
   AND fb.room_category = fa.room_category;

----RevPAR per Hotel

SELECT 
    fb.property_id,
    SUM(fb.revenue_realized) * 1.0 / NULLIF(SUM(fa.capacity), 0) AS RevPAR
FROM fact_bookings fb
JOIN fact_aggregated_bookings fa
    ON fb.property_id = fa.property_id
   AND fb.check_in_date = fa.check_in_date
   AND fb.room_category = fa.room_category
GROUP BY fb.property_id;

---RevPAR per Day

SELECT 
    fb.check_in_date,
    SUM(fb.revenue_realized) * 1.0 / NULLIF(SUM(fa.capacity), 0) AS RevPAR
FROM fact_bookings fb
JOIN fact_aggregated_bookings fa
    ON fb.property_id = fa.property_id
   AND fb.check_in_date = fa.check_in_date
   AND fb.room_category = fa.room_category
GROUP BY fb.check_in_date
ORDER BY fb.check_in_date;

----Daily Sellable Room Nights
SELECT 
    check_in_date,
    SUM(capacity) AS daily_sellable_room_nights
FROM fact_aggregated_bookings_cleaned
GROUP BY check_in_date
ORDER BY daily_sellable_room_nights desc

----DURN – Daily Utilized Room Nights
SELECT 
    check_in_date,
    COUNT(booking_id) AS DURN
FROM fact_bookings
WHERE booking_status = 'Checked Out'
GROUP BY check_in_date
ORDER BY check_in_date;

----Revenue WoW change %
WITH weekly_revenue AS (
    SELECT 
        d.week_no,
        SUM(f.revenue_realized) AS total_revenue
    FROM fact_bookings_cleaned f
    JOIN dim_date_cleaned d 
        ON f.check_in_date = d.date
    WHERE f.booking_status = 'Checked Out'
    GROUP BY d.week_no
)
SELECT 
    week_no,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY week_no) AS prev_week_revenue,
    ROUND(((total_revenue - LAG(total_revenue) OVER (ORDER BY week_no)) 
           / NULLIF(LAG(total_revenue) OVER (ORDER BY week_no),0)) * 100,2) AS WoW_Revenue_Change_Percent
FROM weekly_revenue;


----Occupancy WoW change %

WITH weekly_occ AS (
    SELECT 
        d.week_no,
        SUM(fa.successful_bookings) AS total_booked,
        SUM(fa.capacity) AS total_capacity,
        SUM(fa.successful_bookings)*1.0 / NULLIF(SUM(fa.capacity),0) AS occupancy
    FROM fact_aggregated_bookings_cleaned fa
    JOIN dim_date_cleaned d 
        ON fa.check_in_date = d.date
    GROUP BY d.week_no
)
SELECT 
    week_no,
    occupancy,
    LAG(occupancy) OVER (ORDER BY week_no) AS prev_occ,
    ROUND(((occupancy - LAG(occupancy) OVER (ORDER BY week_no)) 
           / NULLIF(LAG(occupancy) OVER (ORDER BY week_no),0)) * 100,2) AS WoW_Occupancy_Change_Percent
FROM weekly_occ;


----ADR (Average Daily Rate) WoW change %

WITH weekly_adr AS (
    SELECT 
        d.week_no,
        SUM(f.revenue_realized)*1.0 / NULLIF(SUM(CASE WHEN f.booking_status='Checked Out' THEN 1 END),0) AS ADR
    FROM fact_bookings_cleaned f
    JOIN dim_date_cleaned d 
        ON f.check_in_date = d.date
    GROUP BY d.week_no
)
SELECT 
    week_no,
    ADR,
    LAG(ADR) OVER (ORDER BY week_no) AS prev_ADR,
    ROUND(((ADR - LAG(ADR) OVER (ORDER BY week_no)) 
           / NULLIF(LAG(ADR) OVER (ORDER BY week_no),0)) * 100,2) AS WoW_ADR_Change_Percent
FROM weekly_adr;

---RevPAR (Revenue per Available Room) WoW change %

WITH weekly_revpar AS (
    SELECT 
        d.week_no,
        SUM(f.revenue_realized)*1.0 / NULLIF(SUM(fa.capacity),0) AS RevPAR
    FROM fact_bookings_cleaned f
    JOIN fact_aggregated_bookings_cleaned fa 
        ON f.property_id = fa.property_id AND f.check_in_date = fa.check_in_date
    JOIN dim_date_cleaned d 
        ON f.check_in_date = d.date
    GROUP BY d.week_no
)
SELECT 
    week_no,
    RevPAR,
    LAG(RevPAR) OVER (ORDER BY week_no) AS prev_RevPAR,
    ROUND(((RevPAR - LAG(RevPAR) OVER (ORDER BY week_no)) 
           / NULLIF(LAG(RevPAR) OVER (ORDER BY week_no),0)) * 100,2) AS WoW_RevPAR_Change_Percent
FROM weekly_revpar;

----Realisation WoW change %

WITH weekly_realisation AS (
    SELECT 
        d.week_no,
        SUM(f.revenue_realized)*1.0 / NULLIF(SUM(f.revenue_generated),0) AS realisation
    FROM fact_bookings_cleaned f
    JOIN dim_date_cleaned d 
        ON f.check_in_date = d.date
    GROUP BY d.week_no
)
SELECT 
    week_no,
    realisation,
    LAG(realisation) OVER (ORDER BY week_no) AS prev_realisation,
    ROUND(((realisation - LAG(realisation) OVER (ORDER BY week_no)) 
           / NULLIF(LAG(realisation) OVER (ORDER BY week_no),0)) * 100,2) AS WoW_Realisation_Change_Percent
FROM weekly_realisation;

---DSRN (Daily Sellable Room Nights) WoW change %

WITH weekly_dsrn AS (
    SELECT 
        d.week_no,
        SUM(fa.capacity) AS DSRN
    FROM fact_aggregated_bookings_cleaned fa
    JOIN dim_date_cleaned d 
        ON fa.check_in_date = d.date
    GROUP BY d.week_no
)
SELECT 
    week_no,
    DSRN,
    LAG(DSRN) OVER (ORDER BY week_no) AS prev_DSRN,
    ROUND(((DSRN - LAG(DSRN) OVER (ORDER BY week_no)) 
           / NULLIF(LAG(DSRN) OVER (ORDER BY week_no),0)) * 100,2) AS WoW_DSRN_Change_Percent
FROM weekly_dsrn;
