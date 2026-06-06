-- FIVE BUSINESS QUESTIONS
-- These answer the core analytical questions
-- and feed directly into the Python visualizations.
-- ─────────────────────────────────────────────

USE rfm_analysis;


-- ════════════════════════════════════════════
-- Q1: Who are your Champions and what is
--     their combined revenue contribution?
-- ════════════════════════════════════════════

SELECT
    segment,
    COUNT(*)                                            AS customer_count,
    ROUND(SUM(monetary), 2)                            AS total_revenue,
    ROUND(AVG(monetary), 2)                            AS avg_customer_value,
    ROUND(AVG(frequency), 1)                           AS avg_orders,
    ROUND(AVG(recency_days), 0)                        AS avg_days_since_purchase,
    ROUND(
        SUM(monetary) * 100 /
        SUM(SUM(monetary)) OVER (), 2
    )                                                    AS pct_of_total_revenue
FROM v_rfm_segments
WHERE segment = 'Champions'
GROUP BY segment;



-- Bonus: Top 10 individual Champions
SELECT
    customer_id,
    recency_days,
    frequency,
    monetary,
    rfm_string
FROM v_rfm_segments
WHERE segment = 'Champions'
ORDER BY monetary DESC
LIMIT 10;


-- ════════════════════════════════════════════
-- Q2: Which customers are At Risk or about
--     to be lost — and how much revenue
--     is at stake?
-- ════════════════════════════════════════════

SELECT
    segment,
    COUNT(*)                            AS customer_count,
    ROUND(AVG(recency_days), 0)        AS avg_days_since_last_purchase,
    ROUND(SUM(monetary), 2)            AS revenue_at_risk,
    ROUND(AVG(monetary), 2)            AS avg_value_per_customer,
    ROUND(AVG(frequency), 1)           AS avg_historical_orders
FROM v_rfm_segments
WHERE segment IN ('At Risk',
                  'Cannot Lose Them',
                  'About to Sleep',
                  'Hibernating')
GROUP BY segment
ORDER BY revenue_at_risk DESC;


-- ════════════════════════════════════════════
-- Q3: Does the 80/20 rule apply?
--     What % of revenue comes from the
--     top 20% of customers?
-- ════════════════════════════════════════════

WITH customer_quintiles AS (
    SELECT
        customer_id,
        monetary,
        NTILE(5) OVER (ORDER BY monetary ASC) AS quintile
    FROM v_rfm_segments
)
SELECT
    quintile,
    CASE quintile
        WHEN 5 THEN 'Top 20%    (Quintile 5)'
        WHEN 4 THEN 'Upper-Mid  (Quintile 4)'
        WHEN 3 THEN 'Mid        (Quintile 3)'
        WHEN 2 THEN 'Lower-Mid  (Quintile 2)'
        WHEN 1 THEN 'Bottom 20% (Quintile 1)'
    END                                                 AS customer_group,
    COUNT(*)                                            AS customers,
    ROUND(SUM(monetary), 2)                            AS group_revenue,
    ROUND(
        SUM(monetary) * 100 /
        SUM(SUM(monetary)) OVER (), 2
    )                                                    AS pct_of_total_revenue,
    ROUND(
        SUM(SUM(monetary)) OVER (ORDER BY quintile DESC) * 100 /
        SUM(SUM(monetary)) OVER (), 2
    )                                                    AS cumulative_revenue_pct
FROM customer_quintiles
GROUP BY quintile
ORDER BY quintile DESC;


-- ════════════════════════════════════════════
-- Q4: What is the full segment breakdown?
--     (Feeds the campaign strategy table
--      in Python)
-- ════════════════════════════════════════════

SELECT
    segment,
    COUNT(*)                               AS customer_count,
    ROUND(COUNT(*) * 100.0 /
          SUM(COUNT(*)) OVER (), 2)       AS pct_of_customers,
    ROUND(SUM(monetary), 2)               AS total_revenue,
    ROUND(SUM(monetary) * 100 /
          SUM(SUM(monetary)) OVER (), 2)  AS pct_of_revenue,
    ROUND(AVG(monetary), 2)               AS avg_customer_value,
    ROUND(AVG(frequency), 1)              AS avg_orders,
    ROUND(AVG(recency_days), 0)           AS avg_recency_days,
    MIN(rfm_score)                         AS min_rfm_score,
    MAX(rfm_score)                         AS max_rfm_score
FROM v_rfm_segments
GROUP BY segment
ORDER BY total_revenue DESC;


-- ════════════════════════════════════════════
-- Q5: How does Average Order Value differ
--     across segments?
--     (AOV = monetary / frequency)
-- ════════════════════════════════════════════

SELECT
    segment,
    COUNT(*)                                        AS customers,
    ROUND(AVG(monetary / frequency), 2)            AS avg_order_value,
    ROUND(AVG(frequency), 1)                       AS avg_orders_per_customer,
    ROUND(AVG(monetary), 2)                        AS avg_lifetime_value,
    ROUND(MIN(monetary / frequency), 2)            AS min_order_value,
    ROUND(MAX(monetary / frequency), 2)            AS max_order_value,
    RANK() OVER (
        ORDER BY AVG(monetary / frequency) DESC
    )                                               AS aov_rank
FROM v_rfm_segments
GROUP BY segment
ORDER BY avg_order_value DESC;