-- ============================================================
-- Zepto E-Commerce & Inventory Analytics
-- Author: Md Sulaiman Qamar
-- GitHub: https://github.com/DevcodeSulaiman
-- ============================================================
-- DATA CLEANING & EXPLORATION
-- ============================================================

USE zepto_analytics;


-- ============================================================
-- Part 1: Exploring the raw data first
-- Always good to understand what you're working with before touching anything
-- ============================================================

-- how many rows do we have?
SELECT COUNT(*) AS total_raw_rows FROM zepto_raw;
-- 3732 rows total

-- quick look at the data
SELECT * FROM zepto_raw LIMIT 10;

-- checking for nulls across all columns
-- ran this early on and was surprised -- no nulls at all in this dataset
SELECT
    SUM(CASE WHEN category               IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN name                   IS NULL THEN 1 ELSE 0 END) AS null_name,
    SUM(CASE WHEN mrp                    IS NULL THEN 1 ELSE 0 END) AS null_mrp,
    SUM(CASE WHEN discountPercent        IS NULL THEN 1 ELSE 0 END) AS null_discountPercent,
    SUM(CASE WHEN availableQuantity      IS NULL THEN 1 ELSE 0 END) AS null_availableQty,
    SUM(CASE WHEN discountedSellingPrice IS NULL THEN 1 ELSE 0 END) AS null_sellingPrice,
    SUM(CASE WHEN weightInGms            IS NULL THEN 1 ELSE 0 END) AS null_weight,
    SUM(CASE WHEN outOfStock             IS NULL THEN 1 ELSE 0 END) AS null_outOfStock,
    SUM(CASE WHEN quantity               IS NULL THEN 1 ELSE 0 END) AS null_quantity
FROM zepto_raw;

-- what categories do we have?
SELECT DISTINCT category
FROM zepto_raw
ORDER BY category;
-- 14 categories total

-- how many SKUs per category?
SELECT category, COUNT(sku_id) AS sku_count
FROM zepto_raw
GROUP BY category
ORDER BY sku_count DESC;

-- in stock vs out of stock split
-- outOfStock = 0 means in stock, outOfStock = 1 means out of stock
-- Note: this uses the converted TINYINT column from step 01
SELECT
    CASE WHEN outOfStock = 0 THEN 'In Stock' ELSE 'Out of Stock' END AS stock_status,
    COUNT(sku_id) AS sku_count
FROM zepto_raw
GROUP BY outOfStock;

-- checking which product names appear more than once
-- (same product can exist as multiple SKUs in different sizes/weights -- totally expected)
SELECT name, COUNT(sku_id) AS sku_count
FROM zepto_raw
GROUP BY name
HAVING COUNT(sku_id) > 1
ORDER BY COUNT(sku_id) DESC
LIMIT 20;

-- looking for exact duplicate rows (all columns identical)
SELECT category, name, mrp, discountPercent, availableQuantity,
       discountedSellingPrice, weightInGms, outOfStock, quantity,
       COUNT(*) AS occurrences
FROM zepto_raw
GROUP BY category, name, mrp, discountPercent, availableQuantity,
         discountedSellingPrice, weightInGms, outOfStock, quantity
HAVING COUNT(*) > 1;
-- found 2 exact duplicates -- will remove these

-- checking for zero or invalid prices
SELECT * FROM zepto_raw
WHERE mrp = 0 OR discountedSellingPrice = 0;
-- 1 row with mrp = 0, same row has selling price = 0 too -- removing this

-- sanity check: is mrp always >= selling price? (it should be)
SELECT * FROM zepto_raw
WHERE mrp < discountedSellingPrice;
-- good, 0 rows. pricing is consistent

-- any products with 0 weight?
SELECT * FROM zepto_raw WHERE weightInGms = 0;
-- 4 rows. keeping these but will exclude from price-per-gram calculations

-- any products with 0 quantity?
SELECT * FROM zepto_raw WHERE quantity = 0;
-- 6 rows. probably weight-based items, keeping them


-- ============================================================
-- Part 2: Actual cleaning -- creating the final analytical table
-- ============================================================

-- This is the clean table I'll use for all analysis.
-- zepto_products = cleaned version of zepto_raw

DROP TABLE IF EXISTS zepto_products;

CREATE TABLE zepto_products (
    sku_id                 INT AUTO_INCREMENT PRIMARY KEY,
    category               VARCHAR(120)  NOT NULL,
    name                   VARCHAR(200)  NOT NULL,
    mrp                    DECIMAL(10,2) NOT NULL,   -- in Rupees (converted from paise)
    discountedSellingPrice DECIMAL(10,2) NOT NULL,   -- in Rupees (converted from paise)
    discountPercent        DECIMAL(5,2)  NOT NULL,
    availableQuantity      INT           NOT NULL,
    outOfStock             TINYINT(1)    NOT NULL,   -- 0=in stock, 1=out of stock
    weightInGms            INT           NOT NULL,
    quantity               INT           NOT NULL
);


-- Inserting cleaned data with these transformations:
--
-- 1. Removed 1 row where mrp = 0 (invalid -- can't do any pricing analysis on it)
-- 2. Removed 2 exact duplicate rows using ROW_NUMBER() to keep just the first one
-- 3. Converted mrp and discountedSellingPrice from PAISE to RUPEES (divided by 100)
--    The raw CSV stores prices in paise -- e.g. 11000 means Rs. 110.00
--    I noticed this when some prices looked way too high (like Rs. 15000 for onions)

INSERT INTO zepto_products
    (category, name, mrp, discountedSellingPrice, discountPercent,
     availableQuantity, outOfStock, weightInGms, quantity)

SELECT
    category,
    name,
    ROUND(mrp / 100.0, 2)                    AS mrp,
    ROUND(discountedSellingPrice / 100.0, 2) AS discountedSellingPrice,
    discountPercent,
    availableQuantity,
    outOfStock,
    weightInGms,
    quantity

FROM (
    -- using ROW_NUMBER to remove duplicates -- keep the row with lowest sku_id
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY category, name, mrp, discountPercent,
                            availableQuantity, discountedSellingPrice,
                            weightInGms, outOfStock, quantity
               ORDER BY sku_id
           ) AS rn
    FROM zepto_raw
) deduped

WHERE rn = 1       -- drops the 2 duplicate rows
  AND mrp != 0;    -- drops the 1 zero-MRP row


-- ============================================================
-- Part 3: Verifying the cleaned data looks right
-- ============================================================

-- final row count (should be 3729 = 3732 - 1 zero-mrp - 2 duplicates)
SELECT COUNT(*) AS cleaned_row_count FROM zepto_products;

-- make sure no zero prices snuck through
SELECT COUNT(*) AS zero_price_rows
FROM zepto_products
WHERE mrp = 0 OR discountedSellingPrice = 0;

-- check the price conversion worked (should be in rupees now, not paise)
SELECT sku_id, name, mrp, discountedSellingPrice FROM zepto_products LIMIT 10;

-- final stock split
SELECT
    CASE WHEN outOfStock = 0 THEN 'In Stock' ELSE 'Out of Stock' END AS stock_status,
    COUNT(*) AS sku_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_of_total
FROM zepto_products
GROUP BY outOfStock;
-- expect: 3276 in stock (87.9%), 453 out of stock (12.1%)

-- category summary to confirm everything looks good
SELECT
    category,
    COUNT(*)                       AS sku_count,
    ROUND(AVG(mrp), 2)             AS avg_mrp,
    ROUND(AVG(discountPercent), 2) AS avg_discount_pct
FROM zepto_products
GROUP BY category
ORDER BY sku_count DESC;
