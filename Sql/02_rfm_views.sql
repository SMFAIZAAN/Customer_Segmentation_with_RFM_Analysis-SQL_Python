-- ─────────────────────────────────────────────
-- Three layered views that build on each other.
-- View 1 → raw aggregations
-- View 2 → NTILE scores
-- View 3 → segment labels
-- ─────────────────────────────────────────────

USE rfm_analysis;


-- ── VIEW 1: RFM Raw Aggregations ──────────────
-- Calculates Recency, Frequency, and Monetary
-- value for every customer.
-- Reference date = 1 day after the last invoice
-- in the dataset. This simulates "today" for a
-- historical dataset.

CREATE OR REPLACE VIEW v_rfm_raw AS
SELECT
    customer_id,
    DATEDIFF(
        (SELECT DATE_ADD(MAX(invoicedate), INTERVAL 1 DAY)
         FROM transactions),
        MAX(invoicedate)
    )                               AS recency_days,
    COUNT(DISTINCT invoice)         AS frequency,
    ROUND(SUM(total_revenue), 2)   AS monetary
FROM transactions
GROUP BY customer_id;

-- Verify View 1
SELECT * FROM v_rfm_raw
ORDER BY monetary DESC
LIMIT 10;


-- ── VIEW 2: RFM Scored ────────────────────────
-- Assigns scores 1–4 to each customer using
-- NTILE(4) window function.
--
-- SCORING LOGIC:
--   Recency  : ORDER BY recency_days DESC
--              → NTILE 1 = bought ages ago (BAD)
--              → NTILE 4 = bought recently  (GOOD)
--   Frequency: ORDER BY frequency ASC
--              → NTILE 1 = bought rarely    (BAD)
--              → NTILE 4 = buys often       (GOOD)
--   Monetary : ORDER BY monetary ASC
--              → NTILE 1 = spends little    (BAD)
--              → NTILE 4 = spends most      (GOOD)

CREATE OR REPLACE VIEW v_rfm_scored AS
SELECT
    customer_id,
    recency_days,
    frequency,
    monetary,
    NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,
    NTILE(4) OVER (ORDER BY frequency    ASC)  AS f_score,
    NTILE(4) OVER (ORDER BY monetary     ASC)  AS m_score
FROM v_rfm_raw;

-- Verify View 2
SELECT * FROM v_rfm_scored
ORDER BY monetary DESC
LIMIT 10;


-- ── VIEW 3: RFM Segments ──────────────────────
-- Translates numeric scores into business segment
-- labels using CASE WHEN logic.
-- rfm_string: concatenated score e.g. "444"
-- rfm_score : numeric sum e.g. 12

CREATE OR REPLACE VIEW v_rfm_segments AS
SELECT
    customer_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    (r_score + f_score + m_score)      AS rfm_score,
    CONCAT(r_score, f_score, m_score)  AS rfm_string,

    CASE
        WHEN r_score = 4
         AND f_score >= 3
         AND m_score >= 3              THEN 'Champions'

        WHEN r_score >= 3
         AND f_score >= 3              THEN 'Loyal Customers'

        WHEN r_score >= 3
         AND f_score >= 2              THEN 'Potential Loyalists'

        WHEN r_score = 4
         AND f_score = 1               THEN 'New Customers'

        WHEN r_score = 3
         AND f_score = 1               THEN 'Promising'

        WHEN r_score <= 2
         AND f_score >= 3
         AND m_score >= 3              THEN 'At Risk'

        WHEN r_score = 1
         AND f_score >= 3
         AND m_score >= 3              THEN 'Cannot Lose Them'

        WHEN r_score = 2
         AND f_score <= 2
         AND m_score <= 2              THEN 'About to Sleep'

        WHEN r_score = 1
         AND f_score >= 2              THEN 'Hibernating'

        WHEN r_score <= 2
         AND f_score <= 2
         AND m_score <= 2              THEN 'Need Attention'

        ELSE                               'Lost'
    END AS segment

FROM v_rfm_scored;

-- Verify View 3 — full segment distribution
SELECT
    segment,
    COUNT(*)                           AS customers,
    ROUND(AVG(recency_days), 0)       AS avg_recency_days,
    ROUND(AVG(frequency), 1)          AS avg_frequency,
    ROUND(AVG(monetary), 2)           AS avg_monetary,
    ROUND(SUM(monetary), 2)           AS total_revenue
FROM v_rfm_segments
GROUP BY segment
ORDER BY total_revenue DESC;