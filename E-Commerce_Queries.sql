/******************************************************************************************************************************/
/* What are the states and cities that have the greatest concentration of customers/orders?                                   */
/* What could be some reasons for this?                                                                                       */
/******************************************************************************************************************************/

--What areas have the most customers and orders?
SELECT TOP 51 c.customer_city AS city, c.customer_state AS _state, COUNT(DISTINCT c.customer_id) AS count_of_customers
FROM customers c
GROUP BY GROUPING SETS(c.customer_city, c.customer_state)
ORDER BY count_of_customers DESC;

SELECT TOP 51 c.customer_city AS city, c.customer_state AS _state, COUNT(DISTINCT o.order_id) AS numOfOrders
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY GROUPING SETS(c.customer_city, c.customer_state)
ORDER BY numOfOrders DESC;
/*
Both queries return the same result.
The top 5 States with the most customers are SP, RJ, MG, RS, PR.
The top 5 Cities with the most customers are Sao Paulo, Rio De Janeiro, Brasilia, Curitiba, Campinas
*/

--Where are the seller most concentrated in?
SELECT TOP 50 s.seller_city AS city, s.seller_state AS _state, COUNT(s.seller_id) AS count_of_sellers
FROM sellers s
GROUP BY GROUPING SETS(s.seller_city, s.seller_state)
ORDER BY count_of_sellers DESC;
/*
The top 5 States with the most sellers are SP, PR, MG, RC, RJ.
The top 5 Cities with the most sellers are Sao Paulo, Curitiba, Rio De Janeiro, Belo Horizonte, Ribeirao Preto
*/
/*
Based on the results of the queries, there seems to be a correlation between where sellers are located and where
customers and orders are concentrated in.
*/


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
/*
The product categories that have the most items sold are bed_bath_table, sports_leisure, furniture_decor,
health_beauty, housewares.
*/

--What is the average review score of the most popular items?
SELECT t10.product_id, AVG(o_r.review_score) AS average_review
FROM orders o
JOIN order_reviews o_r ON o.order_id = o_r.order_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN top_10_products t10 ON oi.product_id = t10.product_id
GROUP BY t10.product_id
ORDER BY average_review DESC;
/*
The average rating (1 being worst, 5 being best) for the top ten products
ranges from 3.87 to 4.32.
*/

--What are the prices of these products?
SELECT DISTINCT t10.product_id, AVG(oi.price) AS average_price
FROM order_items oi
JOIN top_10_products t10 ON oi.product_id = t10.product_id
GROUP BY t10.product_id
ORDER BY average_price DESC;
/*
The prices of these products range from R$19.99 to R$189.99.
Note: Some or all of these items are sold from multiple sellers and those sellers may sell the same
	  item at different prices. So I found the average price of each item on the _product_id column.
	  Also, the currency used is Brazilian Real (denoted as R$).
*/

--Find if there is a correlation between the price of an item and the review of an item.
SELECT t10.product_id, oi.price, o_r.review_score, COUNT(t10.product_id) AS count_of_score
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN order_reviews o_r ON o.order_id = o_r.order_id
JOIN top_10_products t10 ON oi.product_id = t10.product_id
--WHERE o_r.review_score = 5 OR o_r.review_score = 1
GROUP BY t10.product_id, oi.price, o_r.review_score
ORDER BY t10.product_id, oi.price DESC, o_r.review_score DESC;
/*
There doesn't appear to be any correlation between the price of the product and
the review score that the product recieved. With each price of each product, most
scores fall into either a 4 or a 5.
*/

--What type of payment arrangements are most common with most popular items?
SELECT t10.product_id, op.payment_type, COUNT(op.order_id) AS count_of_payment_type
FROM order_payments op
JOIN orders o ON op.order_id = o.order_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN top_10_products t10 ON oi.product_id = t10.product_id
GROUP BY t10.product_id, t10.number_sold, op.payment_type
ORDER BY t10.number_sold DESC
/*
For the most popular items, credit cards are the most popular payment method.
*/


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
/*
All of the top 10 products are being sold by top performing sellers, particularly from
seller_id 1f50f920176fa81dab994f9023523100.
*/