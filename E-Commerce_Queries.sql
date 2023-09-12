/******************************************************************************************************************************/
/* What are the states and cities that have the greatest concentration of customers/orders?                                   */
/* What could be some reasons for this?                                                                                       */
/******************************************************************************************************************************/

--What areas have the most customers?
SELECT c.customer_city AS city, c.customer_state AS _state, COUNT(DISTINCT c.customer_id) AS count_of_customers
FROM customers c
GROUP BY GROUPING SETS(c.customer_city, c.customer_state)
ORDER BY count_of_customers DESC;

--Where are the seller most concentrated in?
SELECT s.seller_city AS city, s.seller_state AS _state, COUNT(DISTINCT s.seller_id) AS count_of_sellers
FROM sellers s
GROUP BY GROUPING SETS(s.seller_city, s.seller_state)
ORDER BY count_of_sellers DESC;


/******************************************************************************************************************************/
/* What are the most popular items? What are the reviews on popular products like?                                            */
/* Are there any correlations between the price of the items and the reviews they get?                                        */
/* Note: In this dataset, the products, as well as customers, are not named. I can only identify them by their unique ids.    */
/*                                                                                                                            */
/******************************************************************************************************************************/

--What products have been purchased the most?
CREATE VIEW top_10_products AS
	SELECT TOP 10 p.product_id, COUNT(oi.order_id) AS number_sold
	FROM order_items oi
	JOIN products p ON oi.product_id = p.product_id
	GROUP BY p.product_id
	ORDER BY number_sold DESC;

--What are the most popular product categories?
WITH Most_Popular_Products AS
(
	SELECT p.product_id AS _product_id, COUNT(o.order_id) AS number_sold
	FROM order_items oi
	JOIN products p ON oi.product_id = p.product_id
	JOIN orders o ON oi.order_id = o.order_id
	GROUP BY p.product_id
)
SELECT p.product_category_name, pcnt.product_category_name_english, COUNT(mpp.number_sold) AS total_sold
FROM Most_Popular_Products mpp
JOIN products p ON mpp._product_id = p.product_id
JOIN product_category_name_translation pcnt ON p.product_category_name = pcnt.product_category_name
GROUP BY p.product_category_name, pcnt.product_category_name_english
ORDER BY total_sold DESC;

--What is the average price and average review score of the most popular items?
SELECT t10.product_id, AVG(oi.price) AS average_price, AVG(o_r.review_score) AS average_review
FROM orders o
JOIN order_reviews o_r ON o.order_id = o_r.order_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN top_10_products t10 ON oi.product_id = t10.product_id
GROUP BY t10.product_id
ORDER BY average_review DESC;

--Find if there is a correlation between the price of an item and the review of an item.
SELECT t10.product_id, oi.price, o_r.review_score, COUNT(t10.product_id) AS count_of_score
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN order_reviews o_r ON o.order_id = o_r.order_id
JOIN top_10_products t10 ON oi.product_id = t10.product_id
--WHERE o_r.review_score = 5 OR o_r.review_score = 1
GROUP BY t10.product_id, oi.price, o_r.review_score
ORDER BY t10.product_id, oi.price DESC, o_r.review_score DESC;

--What type of payment arrangements are most common with most popular items?
SELECT t10.product_id, op.payment_type, COUNT(op.order_id) AS count_of_payment_type
FROM order_payments op
JOIN orders o ON op.order_id = o.order_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN top_10_products t10 ON oi.product_id = t10.product_id
GROUP BY t10.product_id, t10.number_sold, op.payment_type
ORDER BY t10.number_sold DESC;


/******************************************************************************************************************************/
/* What sellers are performing the best and what reasons could explain why?                                                   */
/*                                                                                                                            */
/******************************************************************************************************************************/

--Find which sellers have the highest sales.
SELECT TOP 20 s.seller_id, ROUND(SUM(oi.price), 2) AS total_sales
FROM sellers s
JOIN order_items oi ON s.seller_id = oi.seller_id
GROUP BY s.seller_id
ORDER BY total_sales DESC;

--Find which of the highest selling sellers have on average the best product reviews.
SELECT s.seller_id, AVG(o_r.review_score) AS average_review, top_20_sales.total_sales
FROM sellers s
JOIN order_items oi ON s.seller_id = oi.seller_id
JOIN orders o ON oi.order_id = o.order_id
JOIN order_reviews o_r ON o.order_id = o_r.order_id
JOIN (
	SELECT TOP 20 s.seller_id, ROUND(SUM(oi.price), 2) AS total_sales
	FROM sellers s
	JOIN order_items oi ON s.seller_id = oi.seller_id
	GROUP BY s.seller_id
	ORDER BY total_sales DESC
) top_20_sales ON s.seller_id = top_20_sales.seller_id
GROUP BY s.seller_id, top_20_sales.total_sales
ORDER BY average_review DESC;

--Are any of the top sellers selling the most popular items?
WITH top_20_sellers AS
(
	SELECT TOP 20 s.seller_id, ROUND(SUM(oi.price), 2) AS total_sales
	FROM sellers s
	JOIN order_items oi ON s.seller_id = oi.seller_id
	GROUP BY s.seller_id
	ORDER BY total_sales DESC
)
SELECT DISTINCT t20s.seller_id, t10.product_id, SUM(oi.order_item_id) AS number_sold
FROM top_10_products t10
JOIN order_items oi ON t10.product_id = oi.product_id
JOIN top_20_sellers t20s ON oi.seller_id = t20s.seller_id
GROUP BY t20s.seller_id, t10.product_id
ORDER BY t20s.seller_id, number_sold DESC;

--What is the rate at which the 'order_delivered_customer_date' predate or meets the 'order_estimated_delivery_date'?
--Does this have a positive correlation with review scores?
CREATE VIEW delivery_outcomes AS
	SELECT o.order_id, o.order_estimated_delivery_date AS estimated_delivery_date, o.order_delivered_customer_date AS delivered_date,
		CASE 
			WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date
				THEN 'On time'
			WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
				THEN 'Late'
			WHEN o.order_delivered_customer_date IS NULL OR o.order_delivered_customer_date = ''
				THEN 'Cancelled'
		END AS delivery_outcome
	FROM orders o;

SELECT COUNT(delivery_outcome) AS count_of_ontime_delivery
FROM delivery_outcomes
WHERE delivery_outcome = 'On time';

SELECT COUNT(delivery_outcome) AS count_of_late_delivery
FROM delivery_outcomes
WHERE delivery_outcome = 'Late';

SELECT COUNT(delivery_outcome) AS count_of_cancelled_delivery
FROM delivery_outcomes
WHERE delivery_outcome = 'Cancelled';

--What percentage of orders are delivered on time?
SELECT TOP 1
ROUND(((
	SELECT CAST(COUNT(delivery_outcome) AS float) --AS count_of_ontime_delivery
	FROM delivery_outcomes
	WHERE delivery_outcome = 'On time'
) / (
	SELECT CAST(COUNT(delivery_outcome) AS float) --AS total_count_of_deliveries
	FROM delivery_outcomes
)) * 100, 5) AS percent_delivered_ontime
FROM delivery_outcomes;

--What percentage of orders are delivered late?
SELECT TOP 1
ROUND(((
	SELECT CAST(COUNT(delivery_outcome) AS float) --AS count_of_late_delivery
	FROM delivery_outcomes
	WHERE delivery_outcome = 'Late'
) / (
	SELECT CAST(COUNT(delivery_outcome) AS float) --AS total_count_of_deliveries
	FROM delivery_outcomes
)) * 100, 5) AS percent_delivered_late
FROM delivery_outcomes;

--What percentage of orders are cancelled?
SELECT TOP 1
ROUND(((
	SELECT CAST(COUNT(delivery_outcome) AS float) --AS count_of_cancelled_deliveries
	FROM delivery_outcomes
	WHERE delivery_outcome = 'Cancelled'
) / (
	SELECT CAST(COUNT(delivery_outcome) AS float) --AS total_count_of_deliveries
	FROM delivery_outcomes
)) * 100, 5) AS percent_cancelled_deliveries
FROM delivery_outcomes;

--Find if orders that have been delivered on time have higher average reviews
--than orders that were delivered late.
SELECT do.delivery_outcome, ROUND(AVG(o_r.review_score), 2) AS average_score
FROM delivery_outcomes do
JOIN order_reviews o_r on do.order_id = o_r.order_id
GROUP BY do.delivery_outcome
ORDER BY average_score DESC;