-- ============================================================
-- Zepto E-Commerce & Inventory Analytics
-- Author: Md Sulaiman Qamar
-- GitHub: https://github.com/DevcodeSulaiman
-- ============================================================
-- BUSINESS ANALYSIS -- SQL Questions
-- ============================================================
-- All prices are in Rupees (Rs.)
-- "Estimated Revenue Opportunity" = selling price x available units
-- This is a catalog/inventory dataset -- NOT actual sales transaction data.
-- So I'm careful to call these estimates, not actual revenue.
-- ============================================================

USE zepto_analytics;


-- ============================================================
-- SECTION A: Product & Category Overview
-- Starting broad -- understanding what the catalog looks like
-- ============================================================

-- Q1. How many SKUs and unique products does each category have?
-- Also added % of total catalog since it's useful context
SELECT
    category,
    COUNT(sku_id)           AS total_skus,
    COUNT(DISTINCT name)    AS distinct_products,
    ROUND(COUNT(sku_id) * 100.0 / SUM(COUNT(sku_id)) OVER (), 1) AS pct_of_catalog
FROM zepto_products
GROUP BY category
ORDER BY total_skus DESC;


-- Q2. What is the in-stock vs out-of-stock breakdown by category?
-- This one is really useful for spotting which categories have supply issues
SELECT
    category,
    COUNT(sku_id)                                                     AS total_skus,
    SUM(CASE WHEN outOfStock = 0 THEN 1 ELSE 0 END)                   AS in_stock,
    SUM(CASE WHEN outOfStock = 1 THEN 1 ELSE 0 END)                   AS out_of_stock,
    ROUND(SUM(CASE WHEN outOfStock = 0 THEN 1 ELSE 0 END) * 100.0
          / COUNT(sku_id), 1)                                          AS availability_rate_pct
FROM zepto_products
GROUP BY category
ORDER BY availability_rate_pct ASC;
-- sorted ascending so worst-availability categories appear first


-- Q3. Which categories have the highest average selling price?
SELECT
    category,
    COUNT(sku_id)                                AS sku_count,
    ROUND(AVG(mrp), 2)                           AS avg_mrp,
    ROUND(AVG(discountedSellingPrice), 2)        AS avg_selling_price,
    ROUND(AVG(discountPercent), 2)               AS avg_discount_pct
FROM zepto_products
GROUP BY category
ORDER BY avg_selling_price DESC;


-- ============================================================
-- SECTION B: Pricing & Discount Analysis
-- Discounts are a big lever in quick-commerce -- wanted to dig into this
-- ============================================================

-- Q4. What are the top 10 most-discounted products?
-- Added stock status too -- interesting to see if discounted items are even available
SELECT DISTINCT
    name,
    category,
    mrp,
    discountedSellingPrice,
    discountPercent,
    ROUND(mrp - discountedSellingPrice, 2)  AS price_reduction,
    CASE WHEN outOfStock = 0 THEN 'In Stock' ELSE 'Out of Stock' END AS stock_status
FROM zepto_products
ORDER BY discountPercent DESC
LIMIT 10;


-- Q5. Which categories discount the most aggressively on average?
SELECT
    category,
    ROUND(AVG(discountPercent), 2)  AS avg_discount_pct,
    ROUND(MIN(discountPercent), 2)  AS min_discount,
    ROUND(MAX(discountPercent), 2)  AS max_discount
FROM zepto_products
GROUP BY category
ORDER BY avg_discount_pct DESC
LIMIT 5;


-- Q6. Which products have the biggest absolute price drop (MRP minus selling price)?
-- Discount % can be misleading on cheap products -- Rs. 5 off a Rs. 10 item isn't impressive
-- Rs. 200 off a Rs. 500 item is actually meaningful
SELECT DISTINCT
    name,
    category,
    mrp,
    discountedSellingPrice,
    discountPercent,
    ROUND(mrp - discountedSellingPrice, 2) AS price_drop_rs
FROM zepto_products
ORDER BY price_drop_rs DESC
LIMIT 10;


-- Q7. Expensive products (MRP > Rs. 500) that are barely discounted (<10%)
-- These might be intentionally positioned as premium -- or they could be underperforming
SELECT DISTINCT
    name,
    category,
    mrp,
    discountedSellingPrice,
    discountPercent
FROM zepto_products
WHERE mrp > 500
  AND discountPercent < 10
ORDER BY mrp DESC;


-- Q8. How does MRP compare to selling price at the category level?
-- Useful to see which categories are giving away the most discount value overall
SELECT
    category,
    ROUND(AVG(mrp), 2)                                      AS avg_mrp,
    ROUND(AVG(discountedSellingPrice), 2)                   AS avg_selling_price,
    ROUND(AVG(mrp) - AVG(discountedSellingPrice), 2)        AS avg_price_reduction,
    ROUND((AVG(mrp) - AVG(discountedSellingPrice))
          / AVG(mrp) * 100, 2)                              AS effective_discount_pct
FROM zepto_products
GROUP BY category
ORDER BY avg_price_reduction DESC;


-- Q9. Products that are heavily discounted but still expensive
-- High discount + still pricey = premium product with promo pricing
-- (discount >= 20% AND selling price still >= Rs. 300)
SELECT DISTINCT
    name,
    category,
    mrp,
    discountedSellingPrice,
    discountPercent
FROM zepto_products
WHERE discountPercent >= 20
  AND discountedSellingPrice >= 300
ORDER BY discountedSellingPrice DESC
LIMIT 15;


-- ============================================================
-- SECTION C: Inventory & Stock Analysis
-- ============================================================

-- Q10. Which categories have the most units available right now?
SELECT
    category,
    SUM(availableQuantity)                                   AS total_units,
    ROUND(SUM(availableQuantity) * 100.0
          / SUM(SUM(availableQuantity)) OVER (), 2)          AS pct_of_inventory
FROM zepto_products
WHERE outOfStock = 0
GROUP BY category
ORDER BY total_units DESC;


-- Q11. Which individual products have the highest inventory?
-- (might indicate overstocking risk)
SELECT
    name,
    category,
    discountedSellingPrice,
    availableQuantity,
    ROUND(discountedSellingPrice * availableQuantity, 2) AS estimated_value
FROM zepto_products
WHERE outOfStock = 0
ORDER BY availableQuantity DESC
LIMIT 15;


-- Q12. High-value products (MRP > Rs. 300) that are currently out of stock
-- These are the ones that hurt the most to be out of
SELECT DISTINCT
    name,
    category,
    mrp,
    discountPercent,
    discountedSellingPrice
FROM zepto_products
WHERE outOfStock = 1
  AND mrp > 300
ORDER BY mrp DESC;


-- Q13. Which categories have the worst out-of-stock rates?
SELECT
    category,
    COUNT(sku_id)                                                      AS total_skus,
    SUM(CASE WHEN outOfStock = 1 THEN 1 ELSE 0 END)                    AS oos_skus,
    ROUND(SUM(CASE WHEN outOfStock = 1 THEN 1 ELSE 0 END) * 100.0
          / COUNT(sku_id), 1)                                           AS oos_rate_pct
FROM zepto_products
GROUP BY category
ORDER BY oos_rate_pct DESC;


-- ============================================================
-- SECTION D: Estimated Revenue Opportunity
-- Again -- these are catalog estimates, not actual sales numbers
-- ============================================================

-- Q14. Estimated revenue opportunity by category
-- = selling price x available units for in-stock products
SELECT
    category,
    SUM(availableQuantity)                                                   AS total_units,
    ROUND(SUM(discountedSellingPrice * availableQuantity), 2)                AS est_revenue_opp,
    ROUND(SUM(discountedSellingPrice * availableQuantity) * 100.0
          / SUM(SUM(discountedSellingPrice * availableQuantity)) OVER (), 2) AS pct_of_total
FROM zepto_products
WHERE outOfStock = 0
GROUP BY category
ORDER BY est_revenue_opp DESC;


-- Q15. Top 15 individual products by estimated inventory value
-- Using RANK() here to show relative position even if I filter later
SELECT
    name,
    category,
    discountedSellingPrice,
    availableQuantity,
    ROUND(discountedSellingPrice * availableQuantity, 2)  AS est_revenue_opp,
    RANK() OVER (ORDER BY discountedSellingPrice * availableQuantity DESC) AS revenue_rank
FROM zepto_products
WHERE outOfStock = 0
ORDER BY est_revenue_opp DESC
LIMIT 15;


-- Q16. Which categories have the most OOS exposure?
-- Since OOS products have 0 units, I can't calculate a value for them directly.
-- Using avg MRP of OOS products as a proxy for the commercial impact of those stockouts.
SELECT
    category,
    COUNT(CASE WHEN outOfStock = 1 THEN 1 END)                AS oos_sku_count,
    ROUND(AVG(CASE WHEN outOfStock = 1 THEN mrp END), 2)      AS avg_mrp_of_oos,
    ROUND(MAX(CASE WHEN outOfStock = 1 THEN mrp END), 2)      AS max_mrp_oos
FROM zepto_products
GROUP BY category
HAVING oos_sku_count > 0
ORDER BY avg_mrp_of_oos DESC;


-- ============================================================
-- SECTION E: Price Per Gram -- Value Analysis
-- ============================================================

-- Q17. Which products give the best value per gram?
-- Only looking at products >= 100g to avoid weird outliers
SELECT DISTINCT
    name,
    category,
    weightInGms,
    discountedSellingPrice,
    ROUND(discountedSellingPrice / weightInGms, 4) AS price_per_gram
FROM zepto_products
WHERE weightInGms >= 100
  AND outOfStock = 0
ORDER BY price_per_gram ASC
LIMIT 15;


-- Q18. Which categories have the best average price-per-gram efficiency?
-- Using NULLIF to avoid division by zero just in case
SELECT
    category,
    COUNT(CASE WHEN weightInGms >= 100 THEN 1 END)      AS valid_weight_skus,
    ROUND(
        SUM(CASE WHEN weightInGms >= 100 THEN discountedSellingPrice END) /
        NULLIF(SUM(CASE WHEN weightInGms >= 100 THEN weightInGms END), 0),
    4)                                                   AS avg_price_per_gram
FROM zepto_products
WHERE outOfStock = 0
GROUP BY category
HAVING valid_weight_skus > 5
ORDER BY avg_price_per_gram ASC;


-- Q19. Grouping products by pack size
-- Small = under 1kg, Medium = 1-5kg, Bulk = 5kg+
SELECT
    CASE
        WHEN weightInGms = 0        THEN 'Weight Not Listed'
        WHEN weightInGms < 1000     THEN 'Small Pack (under 1 kg)'
        WHEN weightInGms < 5000     THEN 'Medium Pack (1 to 5 kg)'
        ELSE                             'Bulk Pack (5 kg and above)'
    END                                       AS pack_size,
    COUNT(sku_id)                             AS sku_count,
    ROUND(AVG(discountedSellingPrice), 2)     AS avg_selling_price,
    ROUND(AVG(discountPercent), 2)            AS avg_discount_pct
FROM zepto_products
GROUP BY pack_size
ORDER BY sku_count DESC;


-- Q20. Total estimated inventory weight per category
-- Just an interesting logistics metric -- how much physical product is sitting in each category
SELECT
    category,
    SUM(weightInGms * availableQuantity)                    AS total_weight_gms,
    ROUND(SUM(weightInGms * availableQuantity) / 1000000, 2) AS total_weight_tonnes
FROM zepto_products
WHERE outOfStock = 0
  AND weightInGms > 0
GROUP BY category
ORDER BY total_weight_gms DESC;


-- ============================================================
-- SECTION F: Risk & Opportunity Classification
-- Trying to segment categories into actionable tiers
-- ============================================================

-- Q21. OOS risk classification by category
-- Thresholds: >15% OOS = High Risk, 8-15% = Moderate, below 8% = Low
-- Based on overall OOS rate of ~12%, these thresholds make sense
WITH category_summary AS (
    SELECT
        category,
        COUNT(sku_id)                                                    AS total_skus,
        SUM(CASE WHEN outOfStock = 0 THEN 1 ELSE 0 END)                 AS in_stock,
        SUM(CASE WHEN outOfStock = 1 THEN 1 ELSE 0 END)                 AS oos_count,
        ROUND(SUM(CASE WHEN outOfStock = 0
                       THEN discountedSellingPrice * availableQuantity
                       ELSE 0 END), 2)                                   AS inventory_value,
        ROUND(SUM(CASE WHEN outOfStock = 1 THEN 1 ELSE 0 END) * 100.0
              / COUNT(sku_id), 1)                                        AS oos_rate_pct
    FROM zepto_products
    GROUP BY category
)
SELECT
    category,
    total_skus,
    in_stock,
    oos_count,
    oos_rate_pct,
    inventory_value,
    CASE
        WHEN oos_rate_pct > 15 THEN 'High OOS Risk'
        WHEN oos_rate_pct >  8 THEN 'Moderate OOS Risk'
        ELSE                        'Low OOS Risk'
    END AS risk_tier
FROM category_summary
ORDER BY oos_rate_pct DESC;


-- Q22. Discount strategy classification
-- Overall average discount is ~7.6%, so:
-- Aggressive = avg above 15%, Moderate = 5-15%, Conservative = below 5%
WITH discount_summary AS (
    SELECT
        category,
        COUNT(sku_id)                   AS sku_count,
        ROUND(AVG(discountPercent), 2)  AS avg_discount_pct,
        ROUND(MIN(discountPercent), 2)  AS min_discount,
        ROUND(MAX(discountPercent), 2)  AS max_discount
    FROM zepto_products
    GROUP BY category
)
SELECT
    category,
    sku_count,
    avg_discount_pct,
    min_discount,
    max_discount,
    CASE
        WHEN avg_discount_pct > 15 THEN 'Aggressive Discounting'
        WHEN avg_discount_pct >= 5 THEN 'Moderate Discounting'
        ELSE                            'Low / No Discounting'
    END AS discount_strategy
FROM discount_summary
ORDER BY avg_discount_pct DESC;
