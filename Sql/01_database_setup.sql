CREATE DATABASE IF NOT EXISTS rfm_analysis
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
    
USE rfm_analysis;

-- Verify the load
SELECT COUNT(*) AS total_rows FROM transactions;

-- Confirm column types
DESCRIBE transactions;

-- Add indexes
CREATE INDEX idx_customer_id
    ON transactions (customer_id);

CREATE INDEX idx_invoicedate
    ON transactions (invoicedate);

CREATE INDEX idx_customer_date
    ON transactions (customer_id, invoicedate);

-- Verify indexes
SHOW INDEXES FROM transactions;

-- Quick sanity check
SELECT
    COUNT(*)                                   AS total_rows,
    COUNT(DISTINCT customer_id)                AS unique_customers,
    COUNT(DISTINCT invoice)                    AS unique_invoices,
    MIN(invoicedate)                           AS earliest_date,
    MAX(invoicedate)                           AS latest_date,
    ROUND(SUM(total_revenue), 2)              AS total_revenue,
    ROUND(AVG(total_revenue), 2)              AS avg_line_revenue
FROM transactions;
