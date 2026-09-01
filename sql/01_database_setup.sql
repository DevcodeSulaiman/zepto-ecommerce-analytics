-- ============================================================
-- Zepto E-Commerce & Inventory Analytics
-- Author: Md Sulaiman Qamar
-- GitHub: https://github.com/DevcodeSulaiman
-- ============================================================
-- STEP 1 -- Setting up the database
-- ============================================================

-- creating the database, run this once
CREATE DATABASE IF NOT EXISTS zepto_analytics
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE zepto_analytics;


-- ============================================================
-- STEP 2 -- Create the raw staging table
-- ============================================================

-- Note: I was originally working with PostgreSQL for this project
-- but converted everything to MySQL 8.0 since that's what I use.
-- Key differences I had to handle:
--   SERIAL  ->  INT AUTO_INCREMENT
--   NUMERIC ->  DECIMAL
--   BOOLEAN ->  TINYINT(1)  (MySQL stores booleans this way)

DROP TABLE IF EXISTS zepto_raw;

CREATE TABLE zepto_raw (
    sku_id                 INT AUTO_INCREMENT PRIMARY KEY,
    category               VARCHAR(120),
    name                   VARCHAR(200)    NOT NULL,
    mrp                    DECIMAL(10,2),
    discountPercent        DECIMAL(5,2),
    availableQuantity      INT,
    discountedSellingPrice DECIMAL(10,2),
    weightInGms            INT,
    outOfStock_raw         VARCHAR(10),   -- had to load as text first (see note below)
    outOfStock             TINYINT(1),   -- 0 = in stock, 1 = out of stock
    quantity               INT
);


-- ============================================================
-- STEP 3 -- Load the CSV
-- ============================================================

-- IMPORTANT: before running this, make sure local_infile is turned on:
--   SET GLOBAL local_infile = 1;
-- and connect with:
--   mysql --local-infile=1 -u root -p zepto_analytics

-- One thing I ran into: the CSV stores outOfStock as 'TRUE'/'FALSE' strings.
-- MySQL's TINYINT(1) doesn't auto-convert those, so I loaded it into a VARCHAR
-- column first and then converted it manually using a CASE statement.
-- Spent some time debugging this before I figured it out!

-- UPDATE THE PATH BELOW to match where the file is on your machine:
LOAD DATA LOCAL INFILE 'D:/download/DA project/zepto-SQL-data-analysis-project-main/data/zepto_v2.csv'
INTO TABLE zepto_raw
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(category, name, mrp, discountPercent, availableQuantity,
 discountedSellingPrice, weightInGms, outOfStock_raw, quantity);

-- convert 'TRUE'/'FALSE' strings to 1/0
UPDATE zepto_raw
SET outOfStock = CASE WHEN UPPER(TRIM(outOfStock_raw)) = 'TRUE' THEN 1 ELSE 0 END;


-- quick sanity check after loading
SELECT COUNT(*) AS total_rows_loaded FROM zepto_raw;
-- should be 3732

-- check stock split
SELECT
    CASE WHEN outOfStock = 0 THEN 'In Stock' ELSE 'Out of Stock' END AS stock_status,
    COUNT(*) AS count
FROM zepto_raw
GROUP BY outOfStock;
-- expect: ~3279 in stock, 453 out of stock
