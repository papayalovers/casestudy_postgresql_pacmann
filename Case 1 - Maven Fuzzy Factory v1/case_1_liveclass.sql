-- Case 1.1 # Perusahaan ingin melihat traffic sebelum tanggal 13 April 2012. 
-- Tampilkan utm source, utm campaign, dan http referer
CREATE VIEW traff_before_april_2012 AS
SELECT 
	utm_source,
	utm_campaign,
	http_referer,
	COUNT(Date(created_at)) AS session
FROM website_sessions
WHERE Date(created_at) < '2012-04-13'
GROUP BY 1, 2, 3
ORDER BY 4 DESC;

-- Case 1.2 # Menghitung conversion dari gsearch nonbrand
WITH test AS (
	SELECT
		utm_source,
		utm_campaign,
		order_id
	FROM website_sessions AS ws
	LEFT JOIN orders USING(website_session_id)
	WHERE Date(ws.created_at) < '2012-04-14' AND utm_source = 'gsearch' AND utm_campaign = 'nonbrand'
)
select
	COUNT(utm_source) AS sessions,
	COUNT(order_id) AS orders,
	COUNT(order_id)::FLOAT / COUNT(utm_source) * 100 AS session_to_order_cvr
FROM test

-- CASE 1.3 # Analysis pada tanggal 11 may 2012 volume traffic dari gsearch nonbrand
SELECT
	EXTRACT(WEEK FROM created_at) AS week,
	DATE_TRUNC('week', created_at)::DATE AS week_start_date,
	-- MIN(created_at::date) as week_start_date,
	COUNT(created_at) AS sessions
FROM website_sessions
WHERE created_at < '2012-05-11' AND utm_source = 'gsearch' AND utm_campaign = 'nonbrand'
GROUP BY 1, 2
ORDER BY 1

-- CASE 1.4 # conversion rate untuk gsearc nonbrand berdasarkan jenis perangkat
SELECT
	device_type,
	COUNT(device_type) AS sessions,
	COUNT(order_id) AS orders,
	COUNT(order_id)::FLOAT / COUNT(device_type) * 100 AS conversion_rate
FROM website_sessions as ws 
LEFT JOIN orders USING(website_session_id)
WHERE ws.created_at < '2012-05-12' AND utm_source = 'gsearch' AND utm_campaign = 'nonbrand'
GROUP BY 1;

-- CASE 2.1 # melihat halaman website mana yang sering dilihat selama website berjalan hingga 10 juni 2012
SELECT 
	pageview_url,
	COUNT(created_at)
FROM website_pageviews
WHERE created_at < '2012-06-10'
GROUP BY 1
ORDER BY 2 DESC

-- Case 2.2 # Halaman pertama yang paling banyak dilihat oleh user setiap masuk ke website hingga 13 juni 2012
SELECT 
	first_url_view,
	COUNT(first_url_view) AS session_hitting_page
FROM (
		SELECT 
			DISTINCT(website_session_id),
			FIRST_VALUE(pageview_url) OVER(PARTITION BY website_session_id ORDER BY created_at) AS first_url_view
		FROM website_pageviews
		WHERE created_at < '2012-06-13'
)
GROUP BY first_url_view

-- CASE 2.3 # menghitung bounce rate
WITH session_info AS (
	SELECT
		website_session_id,
		pageview_url
	FROM website_pageviews
	WHERE created_at < '2012-06-14'
	ORDER BY 1
)

SELECT
	COUNT(website_session_id) AS total_session,
	COUNT(
		CASE
			WHEN session_count = 1 THEN website_session_id 
		END
	) AS single_preview,
	COUNT(
		CASE
			WHEN session_count = 1 THEN website_session_id
		END
	)::FLOAT /  COUNT(website_session_id) * 100 AS conversion_rate
FROM (
	SELECT
		website_session_id,
		COUNT(*) AS session_count
	FROM session_info
	GROUP BY 1
) AS session_count

-- CASE 2.4 
WITH periode_lander_start AS(
	SELECT 
		MIN(created_at) AS start_date
	FROM website_pageviews AS wp
	WHERE pageview_url = '/lander-1'
),
session_info_july AS(
	SELECT
		website_session_id,
		FIRST_VALUE(pageview_url) OVER(PARTITION BY website_session_id ORDER BY wp.created_at) AS first_page
	FROM website_pageviews AS wp
	JOIN website_sessions USING(website_session_id)
	WHERE wp.created_at BETWEEN (SELECT * FROM periode_lander_start) 
		AND '2012-07-29' AND utm_source = 'gsearch'
 		AND utm_campaign = 'nonbrand'	
)
SELECT
	first_page,
	COUNT(DISTINCT website_session_id) AS total_session,
	COUNT(
		CASE
			WHEN session_counted = 1 THEN website_session_id
		END 
	) AS bounced_session,
	COUNT(
		CASE
			WHEN session_counted = 1 THEN website_session_id
		END 
	)::FLOAT / COUNT(DISTINCT website_session_id) * 100 AS conversion_rate
FROM (
	SELECT
		first_page,
		website_session_id,
		COUNT(first_page) AS session_counted
	FROM session_info_july
	GROUP BY 1, 2
)  
GROUP BY 1

-- CASE 2.5 
WITH total_funnel_count AS (
	SELECT 
		website_session_id,
		MAX(
			CASE
				WHEN pageview_url = '/lander-01' THEN 1 ELSE 0
			END
		) AS landing_pg,
		MAX(
			CASE
				WHEN pageview_url = '/products' THEN 1 ELSE 0
			END
		) AS products_pg,
		MAX(
			CASE
				WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0
			END
		) AS fuzzy_pg,
		MAX(
			CASE
				WHEN pageview_url = '/cart' THEN 1 ELSE 0
			END
		) AS cart_pg,
		MAX(
			CASE
				WHEN pageview_url = '/shipping' THEN 1 ELSE 0
			END
		) AS shipping_pg,
		MAX(
			CASE
				WHEN pageview_url = '/billing' THEN 1 ELSE 0
			END
		) AS billing_pg,
		MAX(
			CASE
				WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0
			END
		) AS thankyou_pg
	FROM website_pageviews AS wp
	JOIN website_sessions USING(website_session_id)	
	WHERE wp.created_at BETWEEN (DATE '2012-09-05'::DATE-INTERVAL '1 month') AND '2012-09-05'
	AND utm_source = 'gsearch'
	AND utm_campaign = 'nonbrand'	
	GROUP BY 1
)

SELECT 
	COUNT(website_session_id) AS total_session,
	SUM(products_pg)::FLOAT / COUNT(website_session_id) AS landing_to_products_cr,
	SUM(fuzzy_pg)::FLOAT  /  SUM(products_pg) AS products_to_fuzzy_cr,
	SUM(cart_pg)::FLOAT / SUM(fuzzy_pg) AS fuzzy_to_cart_cr,
	SUM(shipping_pg)::FLOAT / SUM(cart_pg) AS cart_to_shipping_cr,
	SUM(billing_pg)::FLOAT / SUM(shipping_pg) AS shipping_to_billing_cr,
	SUM(thankyou_pg)::FLOAT / SUM(billing_pg) AS billing_to_tq_cr
FROM total_funnel_count


