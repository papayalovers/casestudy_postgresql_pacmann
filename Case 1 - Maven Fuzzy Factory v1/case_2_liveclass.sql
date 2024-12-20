-- CASE 1.1 di awal tahun 2013 perusahaan ingin melihat total revenue dan total margin
SELECT 
	EXTRACT(YEAR FROM created_at) as years,
	EXTRACT(MONTH FROM created_at) as months,
	COUNT(order_id) AS total_order,
	SUM(price_usd) AS total_revenue,
	SUM(price_usd - cogs_usd) AS total_margin
FROM orders
WHERE created_at < '2013-01-05'
GROUP BY 1, 2 
ORDER BY 1, 2

-- CASE 1. 2
SELECT 
	EXTRACT(YEAR FROM ws.created_at) as years,
	EXTRACT(MONTH FROM ws.created_at) as months,
	COUNT(website_session_id) AS total_session,
	COUNT(order_id) AS total_order,
	COUNT(order_id)::FLOAT / COUNT(website_session_id) * 100 AS conversion_rate_of_order,
	COUNT(
		CASE
			WHEN product_id = 1 THEN order_id
		END
	) AS product_one_purchased,
	COUNT(
		CASE
			WHEN product_id = 2 THEN order_id
		END
	) AS product_two_purchased
FROM website_sessions AS ws
LEFT JOIN orders USING(website_session_id)
LEFT JOIN  order_items USING(order_id)
WHERE ws.created_at BETWEEN '2012-04-01' AND '2013-04-05'
GROUP BY 1, 2 
ORDER BY 1, 2

-- CASE 1.3 # performa cross sell mulai 25 september 2013 semenjak cross sell diadakan pada akhir tahun 2013
SELECT
	od.primary_product_id,
	COUNT(DISTINCT od.order_id) orders,
	COUNT(
		CASE
			WHEN oi.product_id = 1 THEN 1
		END
	) AS x_sell_prod1,
	COUNT(
		CASE
			WHEN oi.product_id = 2 THEN 1
		END
	) AS x_sell_prod2,
	COUNT(
		CASE
			WHEN oi.product_id = 3 THEN 1
		END
	) AS x_sell_prod3
FROM
	orders AS od
LEFT JOIN order_items AS oi ON od.order_id = oi.order_id AND oi.is_primary_item=0 -- select where order is not primary item
WHERE od.created_at BETWEEN '2013-09-25' AND '2014-01-01'
GROUP BY 1

-- CASE 1.4 # identifikasi user yang melakukan repeat session pada tanggal 1 juni 2014
CREATE TEMPORARY TABLE new_session AS
SELECT
	user_id,
	website_session_id
FROM website_sessions
WHERE is_repeat_session = 0 
	AND created_at BETWEEN '2014-01-01' AND '2014-06-01'
	
WITH session_history AS (
	SELECT
		ns.user_id,
		ns.website_session_id AS new_session_id,
		ws.website_session_id AS repeat_session_id
	FROM new_session AS ns
	LEFT JOIN website_sessions AS ws ON ns.user_id = ws.user_id
		AND is_repeat_session = 1
		AND ws.created_at BETWEEN '2014-01-01' AND '2014-06-01'
),
user_level AS (
	SELECT
		user_id,
		COUNT(DISTINCT new_session_id) AS new_session,
		COUNT(DISTINCT repeat_session_id) AS repeat_session
	FROM session_history
	GROUP BY 1
	ORDER BY 3 DESC
)
SELECT
	repeat_session,
	COUNT(DISTINCT user_id) AS users
FROM user_level
GROUP BY 1

-- CASE 2.5 # membandingkan jumlah repeat session berdasarkan channel/source
SELECT
	CASE
		WHEN utm_source IS NULL AND http_referer IN ('https://www.gsearch.com','https://www.bsearch.com') THEN 'organic_search'
		WHEN utm_campaign = 'nonbrand' THEN 'paid_nonbrand'
		WHEN utm_campaign = 'brand' THEN 'paid_brand'
		WHEN utm_source IS NULL AND http_referer IS NULL THEN 'direct_type_in'
		WHEN utm_source = 'socialbook' THEN 'paid_social'
	END AS channel_group,
	COUNT(
		CASE
			WHEN is_repeat_session = 0 THEN website_session_id
		END
	) AS new_session,
	COUNT(
		CASE
			WHEN is_repeat_session = 1 THEN website_session_id
		END
	) AS repeat_session
FROM website_sessions
WHERE created_at >= '2014-01-01' AND created_at < '2014-06-08'
GROUP BY 1
ORDER BY 3 DESC

-- CASE 2.6 # menghitung order convension rate antara yang repeat dan tidak
SELECT
	is_repeat_session,
	COUNT(ws.website_session_id) AS sessions,
	COUNT(order_id)::FLOAT/COUNT(ws.website_session_id)*100 AS convension_rate
FROM website_sessions AS ws
LEFT JOIN orders USING(website_session_id)
WHERE ws.created_at BETWEEN '2014-01-01' AND '2014-12-31'
GROUP BY 1