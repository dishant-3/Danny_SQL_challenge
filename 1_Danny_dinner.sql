CREATE DATABASE danny_dinner;

USE danny_dinner ;

CREATE TABLE sales (
  customer_id VARCHAR(1),
  order_date DATE,
  product_id INTEGER
);

INSERT INTO sales
  (customer_id, order_date, product_id)
VALUES
  ('A', CAST('2021-01-01' AS DATE), 1),
  ('A', CAST('2021-01-01' AS DATE), 2),
  ('A', CAST('2021-01-07' AS DATE), 2),
  ('A', CAST('2021-01-10' AS DATE), 3),
  ('A', CAST('2021-01-11' AS DATE), 3),
  ('A', CAST('2021-01-11' AS DATE), 3),
  ('B', CAST('2021-01-01' AS DATE), 2),
  ('B', CAST('2021-01-02' AS DATE), 2),
  ('B', CAST('2021-01-04' AS DATE), 1),
  ('B', CAST('2021-01-11' AS DATE), 1),
  ('B', CAST('2021-01-16' AS DATE), 3),
  ('B', CAST('2021-02-01' AS DATE), 3),
  ('C', CAST('2021-01-01' AS DATE), 3),
  ('C', CAST('2021-01-01' AS DATE), 3),
  ('C', CAST('2021-01-07' AS DATE), 3);
 
CREATE TABLE menu (
  product_id INTEGER,
  product_name VARCHAR(5),
  price INTEGER
);

INSERT INTO menu
  (product_id, product_name, price)
VALUES
  (1, 'sushi', 10),
  (2, 'curry', 15),
  (3, 'ramen', 12);
  

CREATE TABLE members(
  customer_id VARCHAR(1),
  join_date DATE
);

INSERT INTO members
  (customer_id, join_date)
VALUES
  ('A', CAST('2021-01-07' AS DATE)),
  ('B', CAST('2021-01-09' AS DATE));

  --SELECT * FROM sales ;
 -- SELECT * FROM menu ;

-- SELECT * FROM members ;

-- 1. What is the total amount each customer spent at the restaurant?

SELECT t1.customer_id, SUM(t2.price) AS amount_spent
FROM sales AS t1
LEFT JOIN 
menu AS t2
ON t1.product_id = t2.product_id
GROUP BY t1.customer_id
ORDER BY t1.customer_id ;

-- 2. How many days has each customer visited the restaurant?
SELECT customer_id, COUNT(DISTINCT order_date) AS no_of_visits
FROM sales 
GROUP BY customer_id
ORDER BY customer_id ;

-- 3. What was the first item from the menu purchased by each customer?

WITH cte AS
(
SELECT  *,DENSE_RANK() OVER( PARTITION BY customer_id ORDER BY order_date) AS d_rnk
FROM sales
)
SELECT DISTINCT cte.customer_id,t1.product_name
FROM cte
LEFT JOIN
menu AS t1
ON cte.product_id = t1.product_id
WHERE cte.d_rnk =1 ;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT TOP 1 t2.product_name, COUNT(t1.product_id) AS volume_purchased 
FROM sales AS t1
LEFT JOIN 
menu AS t2
ON t1.product_id = t2.product_id
GROUP BY t2.product_name 
ORDER BY volume_purchased DESC;

-- 5. Which item was the most popular for each customer?


WITH cte AS
(
SELECT *,DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY cnt_product DESC) AS d_rnk
FROM
(
SELECT DISTINCT t1.customer_id,t2.product_name,COUNT(t2.product_name) OVER (PARTITION BY t1.customer_id,t2.product_name )AS cnt_product
FROM sales AS t1
LEFT JOIN 
menu AS t2
ON t1.product_id = t2.product_id
) AS t3)
SELECT customer_id,product_name,cnt_product FROM cte WHERE d_rnk=1;

-- 6. Which item was purchased first by the customer after they became a member?

WITH cte AS
(
SELECT t1.customer_id,t1.order_date,t2.join_date ,t3.product_name, DATEDIFF(day,t2.join_date,t1.order_date) AS day_diff
FROM sales AS t1
LEFT JOIN 
members AS t2
ON t1.customer_id = t2.customer_id 
LEFT JOIN 
menu AS t3
ON t1.product_id = t3.product_id
WHERE t2.customer_id  IS NOT NULL
) , cte2 AS
(SELECT *,DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY day_diff ) AS d_rnk
FROM cte WHERE day_diff >=0
) SELECT customer_id,product_name 
FROM cte2 WHERE d_rnk =1 ;

-- 7. Which item was purchased just before the customer became a member?


WITH cte AS
(
SELECT t1.customer_id, t3.product_name, t1.order_date,t2.join_date,DATEDIFF(day,t1.order_date,t2.join_date) AS day_diff
FROM sales AS t1
LEFT JOIN 
members AS t2
ON t1.customer_id = t2.customer_id
LEFT JOIN 
menu AS t3
ON t1.product_id = t3.product_id
WHERE t2.customer_id IS NOT NULL
AND t1.order_date < t2.join_date
) ,cte2 AS
(SELECT customer_id,product_name,order_date,join_date, DENSE_RANK()  OVER (PARTITION BY customer_id ORDER BY day_diff) AS d_rnk
FROM cte
)SELECT customer_id,product_name
FROM cte2 
WHERE d_rnk =1; 

-- 8. What is the total items and amount spent for each member before they became a member?

WITH cte AS
(
SELECT t1.customer_id, t1.order_date, t2.join_date, t3.product_name, t3.price
FROM sales AS t1
LEFT JOIN 
members AS t2
ON t1.customer_id = t2.customer_id
LEFT JOIN
menu AS t3
ON t1.product_id = t3.product_id
WHERE t2.customer_id IS NOT NULL
AND t1.order_date < t2.join_date
) SELECT customer_id , COUNT(product_name) AS total_product, SUM(price) AS total_amount
FROM cte
GROUP BY customer_id;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?


SELECT t1.customer_id,SUM(CASE WHEN t2.product_id = 1 THEN t2.price*20 ELSE t2.price*10 END) AS points
FROM sales AS t1
LEFT JOIN
menu AS t2 
ON t1.product_id = t2.product_id
GROUP BY t1.customer_id ;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, 
-- not just sushi - how many points do customer A and B have at the end of January?


WITH cte AS
(
SELECT t1.customer_id, t1.order_date, t2.join_date,t1.product_id,t3.product_name,t3.price,
CASE WHEN t1.product_id = 1 THEN 1 
WHEN DATEDIFF(day,t2.join_date,t1.order_date) BETWEEN 0 AND 7 THEN 1
ELSE 0 END AS points_flag
FROM sales AS t1
LEFT JOIN 
members AS t2
ON t1.customer_id = t2.customer_id
LEFT JOIN 
menu AS t3 
ON t1.product_id = t3.product_id 
WHERE order_date <= CAST('2021-01-31' AS DATE) AND t1.customer_id IN ('A','B')
) SELECT customer_id, SUM(CASE WHEN points_flag =1 THEN price*20 ELSE price*10 END) AS total_points
FROM cte 
GROUP BY customer_id;

-- Bonus Questions

SELECT * FROM sales;
SELECT * FROM menu;
SELECT * FROM members;

-- Create combined table
SELECT t1.customer_id,t1.order_date,t2.product_name,t2.price,
CASE WHEN t3.customer_id IS NULL THEN 'N' ELSE 'Y' END AS member
FROM sales AS t1
LEFT JOIN 
menu AS t2
ON t1.product_id = t2. product_id
LEFT JOIN
members AS t3
ON t1.customer_id = t3.customer_id ;

-- Create ranking

SELECT  tb1.*, tb2.d_rnk AS ranking
FROM
(
SELECT t1.customer_id,t1.order_date,t2.product_name,t2.price,
CASE WHEN t3.customer_id IS NULL THEN 'N' ELSE 'Y' END AS member
FROM sales AS t1
LEFT JOIN 
menu AS t2
ON t1.product_id = t2.product_id
LEFT JOIN 
members AS t3
ON t1.customer_id = t3.customer_id
) AS tb1
LEFT JOIN
(
SELECT DISTINCT t1.customer_id,t1.order_date,t2.product_name,t2.price,DENSE_RANK() OVER(PARTITION BY t1.customer_id ORDER BY t1.order_date) AS d_rnk
FROM sales AS t1
LEFT JOIN
menu AS t2
ON t1.product_id = t2.product_id
LEFT JOIN 
members AS t3 
ON t1.customer_id = t3.customer_id  
WHERE t1.order_date >= t3.join_date
) AS tb2
ON tb1.customer_id = tb2.customer_id AND tb1.order_date = tb2.order_date ;
