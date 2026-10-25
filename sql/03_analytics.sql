-- =====================================================================
-- 03_analytics.sql : business analysis of ABC Corporation sales
-- Period in the data: 2025-01-01 .. 2026-06-30
-- Techniques: CTEs, JOINs, aggregation, CASE, FILTER,
--             window functions (LAG, SUM OVER, RANK, NTILE, AVG OVER)
-- =====================================================================


-- Q1. KPI overview --------------------------------------------------------
WITH sales AS (
    SELECT COUNT(*)                  AS orders,
           COUNT(DISTINCT client_id) AS customers,
           SUM(total_amount)         AS revenue,
           AVG(total_amount)         AS avg_order_value
    FROM orders
),
refunds AS (
    SELECT SUM(amount) AS refunded, COUNT(DISTINCT order_id) AS refunded_orders
    FROM transactions
    WHERE "type" = 'refund'
)
SELECT s.orders,
       s.customers,
       ROUND(s.revenue, 0)                              AS revenue,
       ROUND(s.avg_order_value, 2)                      AS avg_order_value,
       ROUND(s.orders::numeric / s.customers, 2)        AS orders_per_customer,
       ROUND(r.refunded, 0)                             AS refunded,
       ROUND(100 * r.refunded / s.revenue, 1)           AS refund_rate_pct,
       ROUND(100.0 * r.refunded_orders / s.orders, 1)   AS orders_with_refund_pct
FROM sales s CROSS JOIN refunds r;


-- Q2. Monthly revenue, month-over-month growth and 3-month moving average --
WITH monthly AS (
    SELECT DATE_TRUNC('month', order_date)::date AS month,
           COUNT(*)                              AS orders,
           SUM(total_amount)                     AS revenue
    FROM orders
    GROUP BY 1
)
SELECT month,
       orders,
       ROUND(revenue, 0) AS revenue,
       ROUND(100 * (revenue / LAG(revenue) OVER (ORDER BY month) - 1), 1)    AS mom_growth_pct,
       ROUND(AVG(revenue) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 0)
                                                                            AS moving_avg_3m,
       ROUND(SUM(revenue) OVER (ORDER BY month), 0)                         AS running_total
FROM monthly
ORDER BY month;


-- Q3. Category performance and share of revenue -----------------------------
SELECT p.category,
       COUNT(DISTINCT oi.order_id)                                   AS orders,
       SUM(oi.quantity)                                              AS units_sold,
       ROUND(SUM(oi.quantity * p.price), 0)                          AS revenue,
       ROUND(100 * SUM(oi.quantity * p.price)
                 / SUM(SUM(oi.quantity * p.price)) OVER (), 1)       AS revenue_share_pct,
       ROUND(SUM(oi.quantity * p.price) / SUM(oi.quantity), 2)       AS avg_unit_price
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY revenue DESC;


-- Q4. Gross margin by category ----------------------------------------------
-- unit cost of each product = total delivery cost / units delivered
WITH unit_cost AS (
    SELECT product_id, SUM(cost) / SUM(quantity) AS cost_per_unit
    FROM deliveries
    GROUP BY product_id
),
product_sales AS (
    SELECT p.category,
           SUM(oi.quantity * p.price)          AS revenue,
           SUM(oi.quantity * uc.cost_per_unit) AS cogs
    FROM order_items oi
    JOIN products  p  ON p.product_id  = oi.product_id
    JOIN unit_cost uc ON uc.product_id = oi.product_id
    GROUP BY p.category
)
SELECT category,
       ROUND(revenue, 0)                     AS revenue,
       ROUND(revenue - cogs, 0)              AS gross_profit,
       ROUND(100 * (revenue - cogs) / revenue, 1) AS gross_margin_pct,
       ROUND(100 * (revenue - cogs) / SUM(revenue - cogs) OVER (), 1) AS profit_share_pct
FROM product_sales
ORDER BY gross_profit DESC;


-- Q5. Top-3 products in every category -------------------------------------
WITH product_revenue AS (
    SELECT p.category, p.name,
           SUM(oi.quantity)           AS units,
           SUM(oi.quantity * p.price) AS revenue
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    GROUP BY p.category, p.name
),
ranked AS (
    SELECT *, RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rank_in_category
    FROM product_revenue
)
SELECT category, rank_in_category, name, units, ROUND(revenue, 0) AS revenue
FROM ranked
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;


-- Q6. Refunds: share of orders with a refund, by category in the order -----
WITH refunded AS (
    SELECT DISTINCT order_id FROM transactions WHERE "type" = 'refund'
)
SELECT p.category,
       COUNT(DISTINCT oi.order_id)                                       AS orders_with_category,
       COUNT(DISTINCT oi.order_id) FILTER (WHERE r.order_id IS NOT NULL) AS refunded_orders,
       ROUND(100.0 * COUNT(DISTINCT oi.order_id) FILTER (WHERE r.order_id IS NOT NULL)
                    / COUNT(DISTINCT oi.order_id), 1)                    AS refunded_orders_pct
FROM order_items oi
JOIN products p      ON p.product_id = oi.product_id
LEFT JOIN refunded r ON r.order_id   = oi.order_id
GROUP BY p.category
ORDER BY refunded_orders_pct DESC;


-- Q7. Repeat customers: how much revenue comes from people who come back? ---
WITH per_client AS (
    SELECT client_id, COUNT(*) AS orders, SUM(total_amount) AS revenue
    FROM orders
    GROUP BY client_id
)
SELECT CASE WHEN orders = 1 THEN '1 order'
            WHEN orders = 2 THEN '2 orders'
            WHEN orders BETWEEN 3 AND 5 THEN '3-5 orders'
            ELSE '6+ orders' END                              AS customer_group,
       COUNT(*)                                               AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)     AS customers_pct,
       ROUND(SUM(revenue), 0)                                 AS revenue,
       ROUND(100 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1) AS revenue_pct,
       ROUND(SUM(revenue) / COUNT(*), 0)                      AS revenue_per_customer
FROM per_client
GROUP BY 1
ORDER BY MIN(orders);


-- Q8. Monthly cohort retention ---------------------------------------------
-- cohort = month of the first order; month_n = months since the first order
WITH first_order AS (
    SELECT client_id, DATE_TRUNC('month', MIN(order_date))::date AS cohort
    FROM orders
    GROUP BY client_id
),
activity AS (
    SELECT DISTINCT o.client_id, f.cohort,
           (EXTRACT(YEAR FROM o.order_date) - EXTRACT(YEAR FROM f.cohort)) * 12
         + (EXTRACT(MONTH FROM o.order_date) - EXTRACT(MONTH FROM f.cohort)) AS month_n
    FROM orders o
    JOIN first_order f ON f.client_id = o.client_id
),
cohort_size AS (
    SELECT cohort, COUNT(*) AS customers FROM first_order GROUP BY cohort
)
SELECT a.cohort,
       s.customers AS cohort_size,
       ROUND(100.0 * COUNT(*) FILTER (WHERE month_n = 1) / s.customers, 1) AS m1_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE month_n = 2) / s.customers, 1) AS m2_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE month_n = 3) / s.customers, 1) AS m3_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE month_n = 6) / s.customers, 1) AS m6_pct
FROM activity a
JOIN cohort_size s ON s.cohort = a.cohort
WHERE a.cohort <= DATE '2025-12-01'          -- cohorts with at least 6 months of history
GROUP BY a.cohort, s.customers
ORDER BY a.cohort;


-- Q9. RFM segmentation -------------------------------------------------------
-- R = days since last order (as of 2026-07-01), F = number of orders, M = total spend
WITH rfm AS (
    SELECT client_id,
           DATE '2026-07-01' - MAX(order_date)::date AS recency_days,
           COUNT(*)                                  AS frequency,
           SUM(total_amount)                         AS monetary
    FROM orders
    GROUP BY client_id
),
scored AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,   -- 5 = bought most recently
           NTILE(5) OVER (ORDER BY monetary)          AS m_score    -- 5 = spends the most
    FROM rfm
),
segmented AS (
    SELECT *,
           CASE WHEN r_score >= 4 AND frequency >= 4 THEN '1. Champions'
                WHEN frequency >= 4                  THEN '2. Loyal, cooling down'
                WHEN r_score >= 4 AND frequency >= 2 THEN '3. Promising'
                WHEN r_score >= 4                    THEN '4. New customers'
                WHEN r_score <= 2 AND frequency >= 2 THEN '5. At risk'
                WHEN r_score <= 2                    THEN '6. Lost one-time buyers'
                ELSE '7. Need attention' END AS segment
    FROM scored
)
SELECT segment,
       COUNT(*)                                                AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)      AS customers_pct,
       ROUND(100 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS revenue_pct,
       ROUND(AVG(recency_days), 0)                             AS avg_recency_days,
       ROUND(AVG(frequency), 1)                                AS avg_orders,
       ROUND(AVG(monetary), 0)                                 AS avg_spend
FROM segmented
GROUP BY segment
ORDER BY segment;


-- Q10. Sales team performance -------------------------------------------------
SELECT e.department,
       e.full_name,
       COUNT(o.order_id)                     AS orders,
       ROUND(SUM(o.total_amount), 0)         AS revenue,
       ROUND(AVG(o.total_amount), 2)         AS avg_order_value,
       RANK() OVER (PARTITION BY e.department ORDER BY SUM(o.total_amount) DESC) AS rank_in_dept,
       ROUND(100 * SUM(o.total_amount)
                 / SUM(SUM(o.total_amount)) OVER (PARTITION BY e.department), 1)  AS dept_share_pct
FROM employees e
JOIN orders o ON o.employee_id = e.employee_id
GROUP BY e.department, e.employee_id, e.full_name
ORDER BY e.department, rank_in_dept;


-- Q11. Inventory: days of stock cover based on the last 90 days of sales ----
WITH recent_sales AS (
    SELECT oi.product_id, SUM(oi.quantity) AS units_90d
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_date >= DATE '2026-04-01' AND o.order_date < DATE '2026-07-01'
    GROUP BY oi.product_id
),
stock AS (
    SELECT product_id, SUM(quantity) AS on_hand FROM inventory GROUP BY product_id
),
last_delivery AS (
    SELECT product_id, MAX(delivery_date) AS last_delivery FROM deliveries GROUP BY product_id
)
SELECT p.name,
       p.category,
       s.on_hand,
       COALESCE(r.units_90d, 0)                                AS units_sold_90d,
       ROUND(s.on_hand / NULLIF(r.units_90d / 90.0, 0), 0)     AS days_of_cover,
       l.last_delivery,
       CASE WHEN s.on_hand / NULLIF(r.units_90d / 90.0, 0) < 14 THEN 'REORDER NOW'
            WHEN s.on_hand / NULLIF(r.units_90d / 90.0, 0) < 30 THEN 'Reorder soon'
            ELSE 'OK' END                                      AS status
FROM stock s
JOIN products p           ON p.product_id = s.product_id
LEFT JOIN recent_sales r  ON r.product_id = s.product_id
LEFT JOIN last_delivery l ON l.product_id = s.product_id
ORDER BY days_of_cover NULLS LAST
LIMIT 10;


-- Q12. Data quality checks -------------------------------------------------------
SELECT 'orders whose total_amount differs from items × price' AS check_name,
       COUNT(*) AS problems
FROM orders o
WHERE o.total_amount <> calculate_order_total(o.order_id)
UNION ALL
SELECT 'orders without a payment', COUNT(*)
FROM orders o
WHERE NOT EXISTS (SELECT 1 FROM transactions t WHERE t.order_id = o.order_id AND t."type" = 'payment')
UNION ALL
SELECT 'payments not equal to the order total', COUNT(*)
FROM transactions t
JOIN orders o ON o.order_id = t.order_id
WHERE t."type" = 'payment' AND t.amount <> o.total_amount
UNION ALL
SELECT 'orders without items', COUNT(*)
FROM orders o
WHERE NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.order_id)
UNION ALL
SELECT 'negative stock records', COUNT(*)
FROM inventory WHERE quantity < 0;
