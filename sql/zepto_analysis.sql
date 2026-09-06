-- ============================================================
-- Zepto E-Commerce SQL Data Analysis Project
-- Author: Md Sulaiman Qamar
-- ============================================================


-- ============================================================
-- DATABASE SETUP
-- ============================================================

DROP TABLE IF EXISTS zepto;

CREATE TABLE zepto (
    sku_id                 SERIAL PRIMARY KEY,
    category               VARCHAR(120),
    name                   VARCHAR(150)  NOT NULL,
    mrp                    NUMERIC(8,2),
    discountPercent        NUMERIC(5,2),
    availableQuantity      INTEGER,
    discountedSellingPrice NUMERIC(8,2),
    weightInGms            INTEGER,
    outOfStock             BOOLEAN,
    quantity               INTEGER
);


-- ============================================================
-- DATA EXPLORATION
-- ============================================================

-- count of rows
SELECT COUNT(*) FROM zepto;

-- sample data
SELECT * FROM zepto
LIMIT 10;

-- check for null values in any column
SELECT * FROM zepto
WHERE name IS NULL
   OR category IS NULL
   OR mrp IS NULL
   OR discountPercent IS NULL
   OR discountedSellingPrice IS NULL
   OR weightInGms IS NULL
   OR availableQuantity IS NULL
   OR outOfStock IS NULL
   OR quantity IS NULL;

-- all unique product categories
SELECT DISTINCT category
FROM zepto
ORDER BY category;

-- how many products are in stock vs out of stock
SELECT outOfStock, COUNT(sku_id) AS product_count
FROM zepto
GROUP BY outOfStock;

-- products whose name appears more than once (same product, different SKUs)
SELECT name, COUNT(sku_id) AS "Number of SKUs"
FROM zepto
GROUP BY name
HAVING COUNT(sku_id) > 1
ORDER BY COUNT(sku_id) DESC;


-- ============================================================
-- DATA CLEANING
-- ============================================================

-- check products with price = 0 (invalid entries)
SELECT * FROM zepto
WHERE mrp = 0 OR discountedSellingPrice = 0;

-- remove rows where mrp is 0
DELETE FROM zepto
WHERE mrp = 0;

-- prices in the CSV are stored in paise, convert them to rupees
UPDATE zepto
SET mrp                    = mrp / 100.0,
    discountedSellingPrice = discountedSellingPrice / 100.0;

-- quick check to confirm the conversion looks right
SELECT mrp, discountedSellingPrice FROM zepto LIMIT 10;


-- ============================================================
-- DATA ANALYSIS
-- ============================================================

-- Q1. Top 10 products with the highest discount percentage
SELECT DISTINCT name, mrp, discountPercent
FROM zepto
ORDER BY discountPercent DESC
LIMIT 10;


-- Q2. Products with high MRP (above Rs. 300) that are currently out of stock
SELECT DISTINCT name, mrp
FROM zepto
WHERE outOfStock = TRUE AND mrp > 300
ORDER BY mrp DESC;


-- Q3. Estimated revenue opportunity for each category
-- (selling price x available units -- this is catalog estimate, not actual sales)
SELECT category,
       SUM(discountedSellingPrice * availableQuantity) AS total_revenue
FROM zepto
GROUP BY category
ORDER BY total_revenue DESC;


-- Q4. Products where MRP is above Rs. 500 but discount is less than 10%
-- these could be premium products or ones that need better promotional pricing
SELECT DISTINCT name, mrp, discountPercent
FROM zepto
WHERE mrp > 500 AND discountPercent < 10
ORDER BY mrp DESC, discountPercent DESC;


-- Q5. Top 5 categories offering the highest average discount
SELECT category,
       ROUND(AVG(discountPercent), 2) AS avg_discount
FROM zepto
GROUP BY category
ORDER BY avg_discount DESC
LIMIT 5;


-- Q6. Best value products -- price per gram for items above 100g
-- lower price per gram = better deal for the customer
SELECT DISTINCT name, weightInGms, discountedSellingPrice,
       ROUND(discountedSellingPrice / weightInGms, 2) AS price_per_gram
FROM zepto
WHERE weightInGms >= 100
ORDER BY price_per_gram ASC
LIMIT 15;


-- Q7. Classify products by pack size (Small, Medium, Bulk)
SELECT DISTINCT name, weightInGms,
       CASE
           WHEN weightInGms < 1000 THEN 'Small'
           WHEN weightInGms < 5000 THEN 'Medium'
           ELSE 'Bulk'
       END AS weight_category
FROM zepto
ORDER BY weightInGms;


-- Q8. Total inventory weight per category (in grams)
-- gives an idea of how much physical stock each category is holding
SELECT category,
       SUM(weightInGms * availableQuantity) AS total_weight_gms
FROM zepto
GROUP BY category
ORDER BY total_weight_gms DESC;


-- Q9. Products with the biggest absolute price drop (MRP minus selling price)
-- discount % can be misleading on cheap items, absolute drop is more meaningful
SELECT DISTINCT name, mrp, discountedSellingPrice,
       ROUND(mrp - discountedSellingPrice, 2) AS price_drop
FROM zepto
ORDER BY price_drop DESC
LIMIT 10;


-- Q10. Category-wise count of in-stock vs out-of-stock products
-- useful to spot which categories have supply problems
SELECT category,
       SUM(CASE WHEN outOfStock = FALSE THEN 1 ELSE 0 END) AS in_stock,
       SUM(CASE WHEN outOfStock = TRUE  THEN 1 ELSE 0 END) AS out_of_stock,
       COUNT(sku_id)                                        AS total_skus
FROM zepto
GROUP BY category
ORDER BY out_of_stock DESC;


-- Q11. Products that are heavily discounted (above 20%) but still expensive (above Rs. 300)
-- these are premium products with strong promotions running
SELECT DISTINCT name, category, mrp, discountedSellingPrice, discountPercent
FROM zepto
WHERE discountPercent >= 20 AND discountedSellingPrice >= 300
ORDER BY discountedSellingPrice DESC;


-- Q12. Average MRP, selling price, and discount for each category
-- good overall summary to understand pricing across the catalog
SELECT category,
       ROUND(AVG(mrp), 2)                    AS avg_mrp,
       ROUND(AVG(discountedSellingPrice), 2)  AS avg_selling_price,
       ROUND(AVG(discountPercent), 2)         AS avg_discount_pct
FROM zepto
GROUP BY category
ORDER BY avg_mrp DESC;
