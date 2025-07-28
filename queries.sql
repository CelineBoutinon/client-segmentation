-- Liste de requêtes SQL pour le dashboard :

--1. En excluant les commandes annulées, quelles sont les commandes récentes de moins de 3 mois que les clients ont reçues avec au moins 3 jours de retard ?
WITH max_order_time AS (
    SELECT MAX(sh_order_time) AS max_order_time
    FROM shipping
)
SELECT 
    s.sh_order_id AS "Order ID",
    s.sh_order_time as "Order Date",
    max_order_time as "Today's Date",
    DATEDIFF(s.sh_customer_delivery_actual, s.sh_customer_delivery_estimate) AS 'Delivery delay (in days)'
FROM 
    shipping s
JOIN max_order_time ON 1=1
WHERE 
    s.sh_order_time >= DATE_SUB((SELECT max_order_time FROM max_order_time), INTERVAL 3 MONTH)
    AND DATEDIFF(s.sh_customer_delivery_actual, s.sh_customer_delivery_estimate) >= 3
    AND s.sh_status <> 'canceled'
    ORDER BY DATEDIFF(s.sh_customer_delivery_actual, s.sh_customer_delivery_estimate) DESC;

--2. Qui sont les vendeurs ayant généré un chiffre d'affaires de plus de 100 000Real sur des commandeslivrées via Olist ?
WITH delivered_orders AS (
    SELECT sh_order_id
    FROM shipping 
    WHERE sh_status = 'delivered'
),
delivered_baskets AS (
	SELECT b_order_id, b_product_id, b_price, b_seller_id
    FROM baskets
)
SELECT b.b_seller_id AS Supplier, FORMAT(SUM(b.b_price), 2) AS 'Total Sales', 
COUNT(b_product_id) AS 'Products Sold'
FROM delivered_orders d
LEFT JOIN delivered_baskets b ON b.b_order_id = d.sh_order_id
GROUP BY b.b_seller_id  #, b.b_price #try removing price - include only fields that are not aggregated
# in select clause in group by clause
HAVING SUM(b.b_price) > 100000
ORDER BY SUM(b.b_price) DESC;

--3. Qui sont les nouveaux vendeurs (moins de 3 mois d'ancienneté) qui sont déjà très engagés avec la plateforme (ayant déjà vendu plus de 30 produits) ?
SELECT b.b_seller_id AS 'Supplier', FORMAT(SUM(b.b_price), 2) AS "Total Sales",
    COUNT(DISTINCT b.b_product_id) AS 'Unique Products Sold', 
    COUNT(b.b_product_id) AS 'Total Products Sold', 
    COUNT(DISTINCT s.sh_order_id) AS 'Orders Received', DATE(MIN(s.sh_order_time)) AS min_order_time
FROM shipping s
LEFT JOIN baskets b ON b.b_order_id = s.sh_order_id
WHERE s.sh_status = 'delivered'
GROUP BY b.b_seller_id
#HAVING COUNT(b.b_product_id) > 30 #2 lines
HAVING COUNT(s.sh_order_id)> 30 #same
AND DATE(MIN(s.sh_order_time)) > DATE_SUB((SELECT DATE(MAX(sh_order_time)) FROM shipping), INTERVAL 3 MONTH)
ORDER BY COUNT(b.b_product_id) DESC;

--4. Quels sont les 5 codes postaux, enregistrant plus de 30 reviews, avec le pire review score moyen sur les 12 derniers mois ?
WITH recent_reviews AS (
    SELECT r.r_order_id, r.r_score, r.r_review_id, c.c_zip_code, s.sh_order_time, r.r_creation
    FROM reviews r
    INNER JOIN shipping s ON s.sh_order_id = r.r_order_id #left join gives same result
    INNER JOIN customers c ON c.c_customer_id = s.sh_customer_id #left join gives same result
    WHERE s.sh_order_time >= DATE_SUB((SELECT MAX(sh_order_time) FROM shipping), INTERVAL 12 MONTH)
),
average_scores AS (
    SELECT c_zip_code, COUNT(r.r_review_id) AS review_count, AVG(r.r_score) AS avg_score
    FROM recent_reviews r
    GROUP BY c_zip_code
    HAVING review_count > 30
)
SELECT 
    a.c_zip_code AS "Zip Code", 
    a.avg_score AS "Average Score past 12M",
    a.review_count AS "Nb Reviews past 12M"
FROM 
    average_scores a
ORDER BY 
    a.avg_score ASC 
    LIMIT 5;
