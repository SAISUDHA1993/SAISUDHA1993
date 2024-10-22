CREATE DATABASE Evershop;
USE Evershop;
 create table website_sessions( website_session_id INT,
    created_at DATETIME,
    user_id INT,
    is_repeat_session INT,
    utm_source VARCHAR(45),
    utm_campaign VARCHAR(45),
    utm_content VARCHAR(45),
    device_type VARCHAR(50),
    http_referer VARCHAR(50)
);
select * from website_sessions;

SHOW VARIABLES LIKE 'secure_file_priv';
 
LOAD DATA INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\website_sessions.csv'

INTO TABLE website_sessions

FIELDS TERMINATED BY ','

ENCLOSED BY '"'

LINES TERMINATED BY '\n'

IGNORE 1 ROWS;
CREATE TABLE website_pageviews(
	website_pageview_id INT,	
	created_at DATETIME,
	website_session_id INT,
	pageview_url varchar(255)
);
select * from website_pageviews;
SHOW VARIABLES LIKE 'secure_file_priv';
 
LOAD DATA INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\website_pageviews.csv'
INTO TABLE website_pageviews
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
SHOW TABLES;
DESCRIBE website_sessions;
DESCRIBE orders;
USE evershop;

-- TRAFFIC ANALYSIS
-- IDENTIFYING MOST USEFUL TRAFFIC CHANNELS
WITH session_orders AS (
    -- Step 1: Join website_sessions with orders to identify sessions that led to conversions
    SELECT
        ws.utm_campaign AS traffic_source,  -- Assuming utm_campaign is the traffic source column
        ws.website_session_id AS session_id,
        COUNT(o.order_id) AS total_orders,
        SUM(o.price_usd) AS total_revenue
    FROM
        website_sessions ws
    LEFT JOIN
        orders o ON ws.website_session_id = o.website_session_id  -- Join orders with website_sessions using website_session_id
    GROUP BY
        ws.utm_campaign, ws.website_session_id  -- Group by traffic source and session_id
),

traffic_analysis AS (
    -- Step 2: Aggregate data by traffic source
    SELECT
        traffic_source,
        COUNT(DISTINCT session_id) AS total_sessions,
        SUM(total_orders) AS total_orders,
        SUM(total_revenue) AS total_revenue,
        CASE WHEN COUNT(DISTINCT session_id) = 0 THEN 0 ELSE SUM(total_orders) * 1.0 / COUNT(DISTINCT session_id) END AS conversion_rate,
        CASE WHEN SUM(total_orders) = 0 THEN 0 ELSE SUM(total_revenue) * 1.0 / SUM(total_orders) END AS average_order_value
    FROM
        session_orders
    GROUP BY
        traffic_source
)

-- Step 3: Select and sort the final results to evaluate traffic source performance
SELECT
    traffic_source,
    total_sessions,
    total_orders,
    conversion_rate,
    total_revenue,
    average_order_value
FROM
    traffic_analysis
ORDER BY
    total_revenue DESC, conversion_rate DESC;
---------------------------------------------------------------------------------------------------------------------------    
-- Campaign analysis
WITH campaign_data AS (
    SELECT
        ws.utm_campaign AS campaign_name,
        COUNT(DISTINCT ws.website_session_id) AS total_sessions,
        COUNT(o.order_id) AS total_conversions,
        SUM(o.price_usd) AS total_revenue,
        SUM(o.price_usd) / COUNT(o.order_id) AS average_order_value
    FROM
        website_sessions ws
    LEFT JOIN
        orders o ON ws.website_session_id = o.website_session_id
    GROUP BY
        ws.utm_campaign
)

SELECT
    campaign_name,
    total_sessions,
    total_conversions,
    total_revenue,
    CASE WHEN total_sessions = 0 THEN 0 ELSE total_conversions * 1.0 / total_sessions END AS conversion_rate,
    CASE WHEN total_conversions = 0 THEN 0 ELSE total_revenue * 1.0 / total_conversions END AS revenue_per_conversion
FROM
    campaign_data
ORDER BY
    total_revenue DESC, conversion_rate DESC;
------------------------------------------------------------------------------------------------------------------------
-- Comparing the most to least effective traffic to identify and eliminate wasteful traffic sources and scale the most effective source.

WITH traffic_performance AS (
    -- Step 1: Aggregate performance data by traffic source
    SELECT
        ws.utm_campaign AS traffic_source,
        COUNT(DISTINCT ws.website_session_id) AS total_sessions,
        COUNT(o.order_id) AS total_conversions,
        SUM(o.price_usd) AS total_revenue
    FROM
        website_sessions ws
    LEFT JOIN
        orders o ON ws.website_session_id = o.website_session_id
    GROUP BY
        ws.utm_campaign
),
  
traffic_analysis AS (
    -- Step 2: Calculate effectiveness metrics
    SELECT
        traffic_source,
        total_sessions,
        total_conversions,
        total_revenue,
        CASE WHEN total_sessions = 0 THEN 0 ELSE total_conversions * 1.0 / total_sessions END AS conversion_rate,
        CASE WHEN total_conversions = 0 THEN 0 ELSE total_revenue * 1.0 / total_conversions END AS revenue_per_conversion
    FROM
        traffic_performance
)
  
-- Step 3: Select and sort the results
SELECT
    traffic_source,
    total_sessions,
    total_conversions,
    conversion_rate,
    total_revenue,
    revenue_per_conversion
FROM
    traffic_analysis
ORDER BY
    conversion_rate DESC, revenue_per_conversion DESC;
------------------------------------------------------------------------------------------------------------------------    
-- WEBSITE PERFORMANCE AND ANALYSIS
DESCRIBE website_pageviews;
------------------------------------------------------------------------------------------------------------------------
-- Identify the most and least viewed website pages by the customers to make creative decisions on the enhancement of the pages. 
-- Step 1: Aggregate page view counts by URL
WITH page_view_counts AS (
    SELECT
        pageview_url,            -- Column for the URL of the page
        COUNT(*) AS total_views
    FROM
        website_pageviews
    GROUP BY
        pageview_url
)

-- Step 2: Select and sort pages by view count
SELECT
    pageview_url,
    total_views
FROM
    page_view_counts
ORDER BY
    total_views DESC;  -- Use DESC to get most viewed pages first
-------------------------------------------------------------------------------------------------------------------------    
-- Least Viewed Pages
-- Step 1: Aggregate page view counts by URL
WITH page_view_counts AS (
    SELECT
        pageview_url,            -- Column for the URL of the page
        COUNT(*) AS total_views
    FROM
        website_pageviews
    GROUP BY
        pageview_url
)

-- Step 2: Select and sort pages by view count
SELECT
    pageview_url,
    total_views
FROM
    page_view_counts
ORDER BY
    total_views ASC; -- Use ASC to get least viewed pages first
--------------------------------------------------------------------------------------------------------------------------    
 -- Understanding the pattern and effect of website pages on customer orders and make changes to the website pages and push maximum products to customer orders.   
-- Step 1: Join website_pageviews with orders to link page views to orders
WITH page_order_data AS (
    SELECT
        wp.pageview_url,              -- The URL of the page viewed
        COUNT(DISTINCT o.order_id) AS total_orders,  -- Count unique orders linked to the page
        SUM(o.price_usd) AS total_revenue,  -- Total revenue from orders linked to the page
        COUNT(DISTINCT wp.website_session_id) AS total_sessions  -- Total sessions that included the page
    FROM
        website_pageviews wp
    LEFT JOIN
        orders o ON wp.website_session_id = o.website_session_id
    GROUP BY
        wp.pageview_url
)

-- Step 2: Calculate metrics like conversion rate and average order value per page
SELECT
    pageview_url,
    total_orders,
    total_revenue,
    total_sessions,
    CASE WHEN total_sessions = 0 THEN 0 ELSE total_orders * 1.0 / total_sessions END AS conversion_rate,
    CASE WHEN total_orders = 0 THEN 0 ELSE total_revenue * 1.0 / total_orders END AS average_order_value
FROM
    page_order_data
ORDER BY
    conversion_rate DESC, total_revenue DESC;
------------------------------------------------------------------------------------------------------------------------
-- find the pages with the highest conversion rates:
-- Step 1: Join website_pageviews with orders to link page views to orders
WITH page_order_data AS (
    SELECT
        wp.pageview_url,                              -- The URL of the page viewed
        COUNT(DISTINCT wp.website_session_id) AS total_sessions, -- Total sessions that viewed the page
        COUNT(DISTINCT o.order_id) AS total_orders,   -- Total unique orders linked to the page
        SUM(o.price_usd) AS total_revenue             -- Total revenue from orders linked to the page
    FROM
        website_pageviews wp
    LEFT JOIN
        orders o ON wp.website_session_id = o.website_session_id
    GROUP BY
        wp.pageview_url
)

-- Step 2: Calculate the conversion rate for each page
SELECT
    pageview_url,
    total_sessions,
    total_orders,
    CASE WHEN total_sessions = 0 THEN 0 ELSE total_orders * 1.0 / total_sessions END AS conversion_rate,
    total_revenue
FROM
    page_order_data
ORDER BY
    conversion_rate DESC, total_orders DESC;
--------------------------------------------------------------------------------------------------------------------------
-- Identify Poor-Performing Pages
-- Step 1: Join website_pageviews with orders to link page views to orders
WITH page_order_data AS (
    SELECT
        wp.pageview_url,                              -- The URL of the page viewed
        COUNT(DISTINCT wp.website_session_id) AS total_sessions, -- Total sessions that viewed the page
        COUNT(DISTINCT o.order_id) AS total_orders,   -- Total unique orders linked to the page
        SUM(o.price_usd) AS total_revenue             -- Total revenue from orders linked to the page
    FROM
        website_pageviews wp
    LEFT JOIN
        orders o ON wp.website_session_id = o.website_session_id
    GROUP BY
        wp.pageview_url
)

-- Step 2: Calculate the conversion rate for each page
SELECT
    pageview_url,
    total_sessions,
    total_orders,
    CASE WHEN total_sessions = 0 THEN 0 ELSE total_orders * 1.0 / total_sessions END AS conversion_rate,
    total_revenue
FROM
    page_order_data
ORDER BY
    conversion_rate ASC, total_orders ASC;
    
--------------------------------------------------------------------------------------------------------------------------
-- Analyze Sales and Revenue by Time Period
-- Step 1: Extract the desired time periods from the order timestamps
WITH time_analysis AS (
    SELECT
        DATE_FORMAT(o.created_at, '%Y-%m-%d') AS order_date,       -- Group by day (adjust format for different periods)
        HOUR(o.created_at) AS order_hour,                          -- Group by hour of the day (remove if not needed)
        COUNT(o.order_id) AS total_orders,                         -- Total number of orders
        SUM(o.price_usd) AS total_revenue                          -- Total revenue generated
    FROM
        orders o
    GROUP BY
        order_date, order_hour                                     -- Adjust based on desired time period
)

-- Step 2: Analyze the busy periods by sorting the data
SELECT
    order_date,
    order_hour,
    total_orders,
    total_revenue
FROM
    time_analysis
ORDER BY
    total_revenue DESC,                                            -- Order by revenue (can be adjusted for orders)
    total_orders DESC;
-------------------------------------------------------------------------------------------------------------------------
-- Identify the Product with the Highest Number of Orders
-- Step 1: Aggregate order data by product
WITH product_sales AS (
    SELECT
        p.product_id,
        p.product_name,
        COUNT(oi.order_id) AS total_orders,          -- Counts the number of orders per product
        SUM(oi.price_usd) AS total_revenue           -- Total revenue generated by each product
    FROM
        products p
    JOIN
        order_items oi ON p.product_id = oi.product_id
    GROUP BY
        p.product_id, p.product_name
)

-- Step 2: Select the top-selling products
SELECT
    product_id,
    product_name,
    total_orders,
    total_revenue
FROM
    product_sales
ORDER BY
    total_orders DESC,  -- Sort by the number of orders
    total_revenue DESC; -- In case of tie in orders, sort by revenue
--------------------------------------------------------------------------------------------------------------------------
-- Least-Selling Products
WITH product_sales AS (
    SELECT
        p.product_id,
        p.product_name,
        COUNT(oi.order_id) AS total_orders,          -- Counts the number of orders per product
        SUM(oi.price_usd) AS total_revenue           -- Total revenue generated by each product
    FROM
        products p
    JOIN
        order_items oi ON p.product_id = oi.product_id
    GROUP BY
        p.product_id, p.product_name
)

-- Step 2: Select the least-selling products
SELECT
    product_id,
    product_name,
    total_orders,
    total_revenue
FROM
    product_sales
ORDER BY
    total_orders ASC,  -- Sort by the number of orders in ascending order
    total_revenue ASC; -- In case of tie in orders, sort by revenue
------------------------------------------------------------------------------------------------------------------------
-- Product with Most Refunds
-- Step 1: Aggregate refund data by product
WITH product_refunds AS (
    SELECT
        oi.product_id,
        p.product_name,
        COUNT(r.order_item_refund_id) AS total_refunds,           -- Total number of refunds per product
        SUM(r.refund_amount_usd) AS total_refund_amount           -- Total amount refunded per product
    FROM
        order_item_refunds r
    JOIN
        order_items oi ON r.order_item_id = oi.order_item_id
    JOIN
        products p ON oi.product_id = p.product_id
    GROUP BY
        oi.product_id, p.product_name
)

-- Step 2: Select the product with the most refunds
SELECT
    product_id,
    product_name,
    total_refunds,
    total_refund_amount
FROM
    product_refunds
ORDER BY
    total_refunds DESC,           -- Sort by the number of refunds
    total_refund_amount DESC;    -- In case of tie in refunds, sort by total refunded amount
---------------------------------------------------------------------------------------------------------------
select * from website_sessions;
---------------------------------------------------------------------------------------------------------------
-- monthly trends for Gsearch sessions and orders
WITH gsearch_sessions AS (
    -- Aggregate Gsearch sessions by month
    SELECT
        DATE_FORMAT(created_at, '%Y-%m') AS month,
        COUNT(website_session_id) AS G_sessions
    FROM
        website_sessions
    WHERE
        utm_source = 'Gsearch'
    GROUP BY
        DATE_FORMAT(created_at, '%Y-%m')
),

gsearch_orders AS (
    -- Aggregate orders linked to Gsearch sessions by month
    SELECT
        DATE_FORMAT(o.created_at, '%Y-%m') AS month,
        COUNT(o.order_id) AS total_orders
    FROM
        orders o
    JOIN
        website_sessions ws ON o.website_session_id = ws.website_session_id
    WHERE
        ws.utm_source = 'Gsearch'
    GROUP BY
        DATE_FORMAT(o.created_at, '%Y-%m')
)

-- Combine both CTEs to produce the final report
SELECT
    gs.month,
    gs.G_sessions,
    COALESCE(go.total_orders, 0) AS total_orders
FROM
    gsearch_sessions gs
LEFT JOIN
    gsearch_orders go ON gs.month = go.month
ORDER BY
    gs.month;
----------------------------------------------------------------------------------------------------------------
-- monthly trends for "brand" and "non-brand" campaigns and their associated orders
WITH brand_sessions AS (
    -- Aggregate sessions for brand campaigns by month
    SELECT
        DATE_FORMAT(created_at, '%Y-%m') AS month,
        utm_campaign,
        COUNT(website_session_id) AS total_sessions
    FROM
        website_sessions
    WHERE
        utm_campaign IN ('brand', 'nonbrand')
    GROUP BY
        DATE_FORMAT(created_at, '%Y-%m'),
        utm_campaign
),

brand_orders AS (
    -- Aggregate orders linked to brand and non-brand sessions by month
    SELECT
        DATE_FORMAT(o.created_at, '%Y-%m') AS month,
        ws.utm_campaign,
        COUNT(o.order_id) AS total_orders
    FROM
        orders o
    JOIN
        website_sessions ws ON o.website_session_id = ws.website_session_id
    WHERE
        ws.utm_campaign IN ('brand', 'nonbrand')
    GROUP BY
        DATE_FORMAT(o.created_at, '%Y-%m'),
        ws.utm_campaign
)

-- Combine both CTEs to produce the final report
SELECT
    bs.month,
    bs.utm_campaign,
    bs.total_sessions,
    COALESCE(bo.total_orders, 0) AS total_orders
FROM
    brand_sessions bs
LEFT JOIN
    brand_orders bo ON bs.month = bo.month AND bs.utm_campaign = bo.utm_campaign
ORDER BY
    bs.month, bs.utm_campaign;
--------------------------------------------------------------------------------------------------------------
-- Monthly Trends for Google Search Sessions
SELECT
    DATE_FORMAT(created_at, '%Y-%m') AS month,
    COUNT(*) AS total_sessions
FROM
    website_sessions
WHERE
    utm_source = 'GSearch'
GROUP BY
    DATE_FORMAT(created_at, '%Y-%m')
ORDER BY
    month;
----------------------------------------------------------------------------------------------------------------
-- Monthly Trends for Orders
SELECT
    DATE_FORMAT(created_at, '%Y-%m') AS month,
    COUNT(*) AS total_orders
FROM
    orders
GROUP BY
    DATE_FORMAT(created_at, '%Y-%m')
ORDER BY
    month;
----------------------------------------------------------------------------------------------------------------
-- Monthly Trends  for gsearch Split by Campaign Type: brand and non brand
SELECT
    DATE_FORMAT(created_at, '%Y-%m') AS month,
    utm_campaign,
    COUNT(*) AS total_sessions
FROM
    website_sessions
WHERE
    utm_source = 'GSearch'
GROUP BY
    DATE_FORMAT(created_at, '%Y-%m'),
    utm_campaign
ORDER BY
    month,
    utm_campaign;
---------------------------------------------------------------------------------------------------------------
   -- gsearch monthly sessions and orders split by device type for nonbrand
   SELECT 
    DATE_FORMAT(ws.created_at, '%Y-%m-01') AS month,
    ws.device_type,
    COUNT(ws.website_session_id) AS total_sessions
FROM 
    website_sessions ws
WHERE 
    ws.utm_source = 'gsearch'  
    AND ws.utm_campaign  LIKE '%nonbrand%'  
    AND ws.http_referer not LIKE '%brand%'  
GROUP BY 
    month, ws.device_type
ORDER BY 
    month
LIMIT 1000;

---------------------------------------------------------------------------------------------------------------
-- Non-Brand Orders by Device and Month
SELECT 
    DATE_FORMAT(o.created_at, '%Y-%m-01') AS month,  
    ws.device_type,
    COUNT(o.order_id) AS total_orders
FROM 
    orders o
JOIN 
    website_sessions ws ON o.website_session_id = ws.website_session_id
WHERE 
    ws.utm_source = 'gsearch'  
    AND ws.utm_campaign  LIKE '%nonbrand%'  
    AND ws.http_referer NOT LIKE '%nonbrand%'  
GROUP BY 
    month, ws.device_type
ORDER BY 
    month
LIMIT 1000;
--------------------------------------------------------------------------------------------------------------
-- 3 we're on Gsearch dive into nonbrand, and pull monthly sessions and orders split by device type
SELECT 
    YEAR(w.created_at) AS year,
    MONTHNAME(w.created_at) AS month_name,
    w.device_type,
    COUNT(DISTINCT w.website_session_id) AS Month_wise_sessions,
    COUNT(o.order_id) AS no_of_orders,
    w.utm_source
FROM website_sessions w
LEFT JOIN orders o ON w.website_session_id = o.website_session_id
WHERE w.utm_campaign = 'nonbrand'
GROUP BY year, month_name, w.device_type, w.utm_source
ORDER BY month_name, year
LIMIT 0, 1000;
--------------------------------------------------------------------------------------------------------------------------------------------
-- 4.  monthly trends for Gsearch, alongside monthly trends for each of our other channels
SELECT 
    DATE_FORMAT(ws.created_at, '%Y-%m-01') AS month,
    ws.utm_source AS channel,  
    COUNT(DISTINCT ws.website_session_id) AS total_sessions,  
    COUNT(DISTINCT o.order_id) AS total_orders,  
    (COUNT(DISTINCT o.order_id) / COUNT(DISTINCT ws.website_session_id)) * 100 AS conversion_rate  
FROM 
    website_sessions ws
LEFT JOIN 
    orders o ON ws.website_session_id = o.website_session_id
WHERE 
    ws.utm_source IS NOT NULL  
GROUP BY 
    month, ws.utm_source
ORDER BY 
    month, ws.utm_source
LIMIT 1000;
--------------------------------------------------------------------------------------------------------------------------------------------
-- 5. website performance improvements over the course of the first 8 months pull session to order conversion rates, by month?
SELECT 
    DATE_FORMAT(ws.created_at, '%Y-%m-01') AS month,  
    COUNT(DISTINCT ws.website_session_id) AS total_sessions,  
    COUNT(DISTINCT o.order_id) AS total_orders,  
    (COUNT(DISTINCT o.order_id) / COUNT(DISTINCT ws.website_session_id)) * 100 AS conversion_rate  
FROM 
    website_sessions ws
LEFT JOIN 
    orders o ON ws.website_session_id = o.website_session_id
WHERE 
    ws.created_at BETWEEN '2012-01-01' AND '2012-08-31'  
GROUP BY 
    month
ORDER BY 
    month;
----------------------------------------------------------------------------------------------------------------------------------------
select* from website_sessions where http_referer = 'g search lander test';
select * from orders;
select * from website_pageviews;
-----------------------------------------------------------------------------------------------------------------------------------------
-- 6. I would like to request an analysis to identify which product has the highest success rate. Specifically, could you provide insights into the total revenue generated and the total refund amounts for each product? This will allow us to determine which product demonstrates the most favorable performance metrics.
SELECT 
    p.product_name , round(sum(o.price_usd),1)as total_revenue,
    round(sum(refund_amount_usd),1) as total_refund_amount
    from orders as o
    join order_item_refunds odre on o.order_id = odre.order_id
    join products as p
    on o.primary_product_id = p.product_id
    group by 1;
    ---------------------------------------------------------------------------------------------------------------------------------------
-- 7.For the landing page test you analyzed previously, it would be great to show a full conversions funnel from each of the two orders. You can use the same time period you analyzed last time (Jun 19-Jul 28).
	USE evershop;
SELECT
	website_sessions.website_session_id, 
    website_pageviews.pageview_url, 
    -- website_pageviews.created_at AS pageview_created_at, 
    CASE WHEN pageview_url = '/home' THEN 1 ELSE 0 END AS homepage,
    CASE WHEN pageview_url = '/lander-1' THEN 1 ELSE 0 END AS custom_lander,
    CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS products_page,
    CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page, 
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
    CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_page,
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
FROM website_sessions 
	LEFT JOIN website_pageviews 
		ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE website_sessions.utm_source = 'gsearch' 
	AND website_sessions.utm_campaign = 'nonbrand' 
    AND website_sessions.created_at < '2012-07-28'
		AND website_sessions.created_at > '2012-06-19'
ORDER BY 
	website_sessions.website_session_id,
    website_pageviews.created_at;


CREATE TEMPORARY TABLE session_level_made_it_flagged
SELECT
	website_session_id, 
    MAX(homepage) AS saw_homepage, 
    MAX(custom_lander) AS saw_custom_lander,
    MAX(products_page) AS product_made_it, 
    MAX(mrfuzzy_page) AS mrfuzzy_made_it, 
    MAX(cart_page) AS cart_made_it,
    MAX(shipping_page) AS shipping_made_it,
    MAX(billing_page) AS billing_made_it,
    MAX(thankyou_page) AS thankyou_made_it
FROM(
SELECT
	website_sessions.website_session_id, 
    website_pageviews.pageview_url, 
    -- website_pageviews.created_at AS pageview_created_at, 
    CASE WHEN pageview_url = '/home' THEN 1 ELSE 0 END AS homepage,
    CASE WHEN pageview_url = '/lander-1' THEN 1 ELSE 0 END AS custom_lander,
    CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS products_page,
    CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page, 
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
    CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_page,
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
FROM website_sessions 
	LEFT JOIN website_pageviews 
		ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE website_sessions.utm_source = 'gsearch' 
	AND website_sessions.utm_campaign = 'nonbrand' 
    AND website_sessions.created_at < '2012-07-28'
		AND website_sessions.created_at > '2012-06-19'
ORDER BY 
	website_sessions.website_session_id,
    website_pageviews.created_at
) AS pageview_level

GROUP BY 
	website_session_id
;


-- then this would produce the final output, part 1
SELECT
	CASE 
		WHEN saw_homepage = 1 THEN 'saw_homepage'
        WHEN saw_custom_lander = 1 THEN 'saw_custom_lander'
        ELSE 'uh oh... check logic' 
	END AS segment, 
    COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END) AS to_products,
    COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) AS to_mrfuzzy,
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS to_cart,
    COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) AS to_shipping,
    COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) AS to_billing,
    COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id ELSE NULL END) AS to_thankyou
FROM session_level_made_it_flagged 
GROUP BY 1
;


-- then this as final output part 2 - click rates

SELECT
	CASE 
		WHEN saw_homepage = 1 THEN 'saw_homepage'
        WHEN saw_custom_lander = 1 THEN 'saw_custom_lander'
        ELSE 'uh oh... check logic' 
	END AS segment, 
	COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT website_session_id) AS lander_click_rt,
    COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END) AS products_click_rt,
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) AS mrfuzzy_click_rt,
    COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS cart_click_rt,
    COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) AS shipping_click_rt,
    COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) AS billing_click_rt
FROM session_level_made_it_flagged
GROUP BY 1
;


/* 08.  I’d love for you to quantify the impact of our billing test, as well. Please analyze the lift generated from the test 
(Sep 10 – Nov 10), in terms of revenue per billing page session, and then pull the number of billing page sessions 
for the past month to understand monthly impact*/

use evershop;
create temporary table billing_pages
select
	website_pageviews.website_session_id,
    website_pageviews.pageview_url as billing_version_seen,
    orders.order_id,
    orders.price_usd
from website_pageviews
	left join orders
		on website_pageviews.website_session_id=orders.website_session_id
where website_pageviews.created_at>'2012-09-10'
and website_pageviews.created_at<'2012-11-10'
and website_pageviews.pageview_url in ('/billing','/billing-2');

-- select*from billing_pages

select 
	billing_version_seen,
    count(distinct website_session_id) as sessions,
    SUM(price_usd)/count(distinct website_session_id) as revenue_per_billing_page_seen
from billing_pages
group by 1;

-- here in results for billing page RPBP = 0.4566 but for billing-2 page RPBP = 0.6269
-- as we got increase of 31.339-22.826 = 8.512 dollars has increased per session seen by changing billing page to billing-2 page

-- now we calculate how revenue generated for last whole month from this change.
-- find last month total session from billing-2 and multiply with this 8.512 to get total revenue

select 
	count(website_session_id) as billing_session_last_mon
from website_pageviews
where website_pageviews.pageview_url  in ('/billing','/billing-2')
and created_at>'2012-09-10'
and created_at<'2012-11-10'

-- result is 1311 sessions are there in last month.
-- 1311*8.512= 11159.232 dollars are the last month revenue from billing-2 page change test
-- $11,159 revenue last month


    



    






    









 
