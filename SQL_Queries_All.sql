/* ==============================================================
   
   SQL ANALYSIS PROJECT
   
   Real Estate Transactions Dataset
   Source: Dubai Land Department (United Arab Emirates)

   Author: Hella Gyergyák
   Date of Publication: 06-10-2025

   Description: 
   SQL-based analysis of apartment sales in Dubai  (Jan–Sep 2025). 
   Focus on pricing trends, transaction status, and area insights. 
   Includes  two  detailed  tables  for  JVC to explore flat type 
   distribution and price vs size relationships.

   SQL Flavour: Microsoft SQL Server

   ============================================================== */




-- ==============================================================
-- SECTION 1: Table Updates
-- ==============================================================

-- 1. Function to Convert Selected Text to Title Case

CREATE FUNCTION dbo.ToTitleCase (@text VARCHAR(200))
RETURNS VARCHAR(200)
AS
BEGIN
    DECLARE @result VARCHAR(200) = LOWER(@text);
    DECLARE @pos INT = 1;

    WHILE @pos <= LEN(@result)
    BEGIN
        IF @pos = 1 OR SUBSTRING(@result, @pos - 1, 1) = ' '
            SET @result = STUFF(
                @result,
                @pos,
                1,
                UPPER(SUBSTRING(@result, @pos, 1))
            );
        SET @pos = @pos + 1;
    END

    RETURN @result;
END;



-- 2. Update Area Names in Original Table

UPDATE dldjansep2025.dbo.[transactions-2025-10-04]
    SET AREA_EN = dbo.ToTitleCase(AREA_EN);



-- 3. Update Area Name of Island 2

UPDATE dldjansep2025.dbo.[transactions-2025-10-04]
    SET AREA_EN = 'Jumeirah Island 2'
    WHERE AREA_EN = 'Island 2';




-- ==============================================================
-- SECTION 2: Descriptive Analysis
-- ==============================================================

-- 1. Average Price Per Squermeter by Area and Status

SELECT 
	area_en AS area,
	is_offplan_en AS status,
	ROUND(AVG(trans_value),2) AS avg_price_AED,
	ROUND(AVG(trans_value/ACTUAL_AREA),2) AS avg_psqm_AED,
	COUNT (*) AS total_transactions
FROM dldjansep2025.dbo.[transactions-2025-10-04]
WHERE PROP_SB_TYPE_EN IN ('Flat')
GROUP BY area_en, is_offplan_en
ORDER BY area_en, is_offplan_en;



-- 2. Market Share of Off-Plan vs Ready Apartments

SELECT 
	area_en AS area,
	is_offplan_en AS status,
	COUNT (*) AS total_transactions,
	CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY area_en) AS decimal(5,2)) AS percent_share
FROM dldjansep2025.dbo.[transactions-2025-10-04]
WHERE prop_sb_type_en IN ('Flat')
GROUP BY area_en, is_offplan_en
ORDER BY area_en, percent_share DESC;



-- 3. Identify Hotspots for Off-Plan Pricing

SELECT 
	area_en AS area,
	COUNT (*) AS total_transactions,
	ROUND(AVG(trans_value/actual_area),2) AS avg_psqm_AED
FROM dldjansep2025.dbo.[transactions-2025-10-04]
WHERE prop_sb_type_en IN ('Flat') AND
		is_offplan_en = 'Off-Plan'
GROUP BY area_en
ORDER BY avg_psqm_AED DESC;



-- 4. Compute Price Gaps Between Off-Plan and Ready Properties by Areas

WITH area_prices AS (
SELECT 
	area_en,
	is_offplan_en,
	ROUND(AVG(trans_value/ACTUAL_AREA),2) AS avg_psqm
FROM dldjansep2025.dbo.[transactions-2025-10-04]
WHERE prop_sb_type_en IN ('Flat')
GROUP BY area_en, is_offplan_en
)

SELECT
	a.area_en AS area,
	a.avg_psqm AS offplan_psqm_AED,
	b.avg_psqm AS ready_psqm_AED,
	(a.avg_psqm - b.avg_psqm) AS price_gap_AED
FROM area_prices AS a
JOIN area_prices AS b
ON a.area_en = b.area_en
AND a.is_offplan_en = 'Off-Plan'
AND b.is_offplan_en = 'Ready'
ORDER BY price_gap_AED DESC;




-- ==============================================================
-- SECTION 3: Ranking Insights and Trends
-- ==============================================================

-- 1. Ranking Based on Average Price Per Squermeter

WITH area_avg AS (
    SELECT
        area_en,
        ROUND(AVG(trans_value / actual_area), 2) AS avg_psqm_AED
    FROM dldjansep2025.dbo.[transactions-2025-10-04]
    WHERE prop_sb_type_en = 'Flat'
    GROUP BY area_en
)
SELECT
    area_en,
    avg_psqm_AED,
    RANK() OVER (ORDER BY avg_psqm_AED DESC) AS price_rank
FROM area_avg
ORDER BY price_rank;



-- 2. Ranking Based Transaction Volume per Status (Off-Plan, Ready)
--    Listing the Top 10 Areas

WITH area_volume AS (
    SELECT 
        area_en AS area,
        is_offplan_en AS status,
        COUNT(*) AS transactions
    FROM dldjansep2025.dbo.[transactions-2025-10-04]
    GROUP BY area_en, is_offplan_en
),
ranked AS (
    SELECT
        area,
        status,
        transactions,
        RANK() OVER (PARTITION BY status ORDER BY transactions DESC) AS volume_rank
    FROM area_volume
)
SELECT
    area,
    status,
    transactions,
    volume_rank
FROM ranked
WHERE volume_rank <= 10
ORDER BY status, volume_rank;



-- 3. Monthly Price Trends per Area

SELECT 
	area_en AS area,
	is_offplan_en AS status,
	LEFT(instance_date, 7) AS transaction_month,
	ROUND(AVG(trans_value / actual_area), 2) AS avg_psqm_AED
FROM dldjansep2025.dbo.[transactions-2025-10-04]
GROUP BY area_en, is_offplan_en, LEFT(instance_date, 7)
ORDER BY area_en, transaction_month, is_offplan_en;




-- ==============================================================
-- SECTION 4: JVC Area Analysis
-- ==============================================================

-- 1. Exploreing Apartment Type Distribution

SELECT 
	rooms_en AS type,
	ROUND(AVG(actual_area), 2) AS avg_size,
	ROUND(AVG(trans_value), 2) AS avg_price_AED,
	ROUND(AVG(trans_value / actual_area), 2) AS avg_psqm_AED,
	COUNT(*) AS total,
	CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS decimal (5,2)) AS percent_share
FROM dldjansep2025.dbo.[transactions-2025-10-04]
WHERE prop_sb_type_en = 'Flat' 
	AND is_offplan_en = 'Off-Plan'
AND area_en = 'JUMEIRAH VILLAGE CIRCLE' 
AND rooms_en IS NOT NULL
GROUP BY rooms_en
ORDER BY avg_size;



-- 2. Exploreing Apartment Price vs Size Relationships

WITH room_stats AS (
    SELECT 
        rooms_en,
        ROUND(AVG(actual_area), 2) AS avg_size,
        ROUND(AVG(trans_value), 2) AS avg_price_AED
    FROM dldjansep2025.dbo.[transactions-2025-10-04]
    WHERE prop_sb_type_en = 'Flat' 
      AND area_en = 'JUMEIRAH VILLAGE CIRCLE' 
      AND rooms_en IS NOT NULL
    GROUP BY rooms_en
)
SELECT 
    rooms_en AS type,
    avg_size,
    LAG(avg_size) OVER (ORDER BY avg_size) AS prev_avg_size,
    avg_price_AED,
    LAG(avg_price_AED) OVER (ORDER BY avg_price_AED) AS prev_avg_price_AED,
    ROUND(avg_size / NULLIF(LAG(avg_size) OVER (ORDER BY avg_size), 0), 2) AS size_gain,
    ROUND(avg_price_AED / NULLIF(LAG(avg_price_AED) OVER (ORDER BY avg_price_AED), 0), 2) AS price_increase
FROM room_stats
ORDER BY avg_size;
