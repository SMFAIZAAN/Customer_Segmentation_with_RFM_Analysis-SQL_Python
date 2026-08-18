# 🛒 Customer Segmentation with RFM Analysis — SQL + Python

_End-to-end customer segmentation across 5,848 customers from a UK e-commerce retailer — scored on Recency, Frequency, and Monetary value using MySQL views and NTILE scoring, then visualised in Python (Plotly). Segments every customer into 1 of 11 groups and maps each group to a targeted marketing action._

---

## 📌 Table of Contents
- <a href="#overview">Overview</a>
- <a href="#business-problem">Business Problem</a>
- <a href="#dataset">Dataset</a>
- <a href="#tools--technologies">Tools & Technologies</a>
- <a href="#project-structure">Project Structure</a>
- <a href="#data-cleaning--preparation">Data Cleaning & Preparation</a>
- <a href="#exploratory-data-analysis-eda">Exploratory Data Analysis (EDA)</a>
- <a href="#sql-architecture--key-queries">SQL Architecture & Key Queries</a>
- <a href="#sample-outputs">Sample Outputs</a>
- <a href="#how-to-run-this-project">How to Run This Project</a>
- <a href="#final-recommendations">Final Recommendations</a>

---

<h2><a class="anchor" id="overview"></a>Overview</h2>

This project applies the RFM framework (Recency, Frequency, Monetary) to segment 5,848 customers from a UK online retailer into 11 actionable groups. The full pipeline runs from raw CSV through Python-based cleaning, MySQL ingestion via SQLAlchemy, three layered SQL views (raw → scored → segmented), and Plotly-based visualisations. Champions (1,008 customers) drive **57.8% of total revenue**. At Risk customers (632) represent **11.7% of revenue** — £1,983,300 — without having purchased recently. Each segment receives a concrete, data-backed campaign recommendation.

---

<h2><a class="anchor" id="business-problem"></a>Business Problem</h2>

E-commerce businesses often treat all customers the same. This project answers five business questions:

1. **Who are Champions and what % of revenue do they drive?**
2. **Which customers are At Risk — and how much revenue is at stake?**
3. **Does the 80/20 rule hold?** What % of revenue comes from the top 20% of customers?
4. **What is the full segment breakdown** across the customer base?
5. **How does Average Order Value (AOV) differ across segments?**

---

<h2><a class="anchor" id="dataset"></a>Dataset</h2>

| Detail | Value |
|---|---|
| **Dataset** | [Online Retail II — UCI Machine Learning Repository](https://archive.ics.uci.edu/dataset/502/online+retail+ii) |
| **Rows (raw)** | ~1,067,371 transactions |
| **Rows (after cleaning)** | ~824,000 rows |
| **Customers segmented** | 5,848 unique customers |
| **Period** | December 2009 – December 2011 |
| **Region** | UK-based online retailer |
| **Format** | `.csv` loaded into MySQL via `pandas.to_sql()` |

---

<h2><a class="anchor" id="tools--technologies"></a>Tools & Technologies</h2>

| Tool | Purpose |
|---|---|
| Python (Pandas, NumPy) | Data cleaning and EDA |
| SQLAlchemy | Python → MySQL bridge for loading cleaned data |
| MySQL 8 / MySQL Workbench | View creation and business query execution |
| Plotly Express / Graph Objects | Interactive segment visualisations |
| Matplotlib / Seaborn | Static EDA charts |
| Jupyter Notebook | Analysis environment |

---

<h2><a class="anchor" id="project-structure"></a>Project Structure</h2>

```
rfm-analysis/
│
├── RFM_Analysis.ipynb            # Full notebook: EDA → cleaning → MySQL load → viz
├── 01_database_setup.sql         # DB creation, indexes, sanity checks
├── 02_rfm_views.sql              # Three layered views (raw → scored → segments)
├── 03_Business_Questions.sql     # Five business queries (Q1–Q5)
├── requirements.txt              # Python dependencies
│
└── assets/                       # Extracted notebook visualisations
    ├── viz1_customer_count.png
    ├── viz2_revenue_by_segment.png
    ├── viz3_rfm_heatmap.png
    ├── viz4_recency_vs_monetary.png
    ├── viz5_pareto.png
    └── viz6_strategy_table.png
```

---

<h2><a class="anchor" id="data-cleaning--preparation"></a>Data Cleaning & Preparation</h2>

All cleaning done in Python (Pandas) before loading to MySQL:

- Removed cancellations — negative quantities excluded from revenue calculations
- Removed non-product stock codes: `POST`, `DOT`, `BANK CHARGES`, `PADS`, and similar
- Dropped rows with missing `Customer ID` — ~135,000 rows removed
- Removed zero-price items (samples and data entry errors)
- Capped unit price at the 99.9th percentile to suppress bulk-order outliers
- Created `total_revenue = quantity × price` as a derived column
- Loaded cleaned ~824,000 rows into MySQL via `pandas.to_sql()` with SQLAlchemy

---

<h2><a class="anchor" id="exploratory-data-analysis-eda"></a>Exploratory Data Analysis (EDA)</h2>

**Segment Distribution — Customer Count:**

After segmentation, 5,848 customers distributed across 11 groups. Loyal Customers (1,093) and Champions (1,008) are the two largest segments. At Risk (632) and About to Sleep (680) together represent 1,312 customers who need re-engagement. Cannot Lose Them has 0 customers in this dataset — no one meets the strict criteria of high frequency, high monetary, and recency score of 1.

<img width="1093" height="550" alt="viz1_customer_count" src="https://github.com/user-attachments/assets/cb8245af-2016-4564-bddc-7b3151ab2c9b" />

**Key EDA stats:**
- Loyal Customers: **1,093** | Champions: **1,008** | Need Attention: **807**
- About to Sleep: **680** | At Risk: **632** | Potential Loyalists: **607**
- Hibernating: **480** | Lost: **325** | Promising: **136** | New Customers: **80**

---

<h2><a class="anchor" id="sql-architecture--key-queries"></a>SQL Architecture & Key Queries</h2>

Three layered views build on each other — raw → scored → segmented.

```
transactions (raw table)
      │
      ▼
v_rfm_raw          ← Recency, Frequency, Monetary per customer
      │
      ▼
v_rfm_scored       ← NTILE(4) scores (1–4) on each dimension
      │
      ▼
v_rfm_segments     ← CASE WHEN logic maps scores → 11 segment labels
```

---

### View 1 — Raw RFM Aggregations

```sql
CREATE OR REPLACE VIEW v_rfm_raw AS
SELECT
    customer_id,
    DATEDIFF(
        (SELECT DATE_ADD(MAX(invoicedate), INTERVAL 1 DAY) FROM transactions),
        MAX(invoicedate)
    )                               AS recency_days,
    COUNT(DISTINCT invoice)         AS frequency,
    ROUND(SUM(total_revenue), 2)   AS monetary
FROM transactions
GROUP BY customer_id;
```

Reference date = 1 day after the dataset's latest invoice. Simulates "today" for a historical dataset without hardcoding a date.

---

### View 2 — NTILE Scoring

```sql
CREATE OR REPLACE VIEW v_rfm_scored AS
SELECT
    customer_id,
    recency_days, frequency, monetary,
    NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,
    NTILE(4) OVER (ORDER BY frequency    ASC)  AS f_score,
    NTILE(4) OVER (ORDER BY monetary     ASC)  AS m_score
FROM v_rfm_raw;
```

Score 4 = best. Recency ordered `DESC` so recent buyers score 4. Frequency and Monetary ordered `ASC` so `NTILE` assigns 4 to top buyers and spenders. Using `NTILE(4)` over fixed thresholds makes scoring dataset-agnostic — no hardcoded percentile cutoffs.

---

### View 3 — Segment Labels

```sql
CREATE OR REPLACE VIEW v_rfm_segments AS
SELECT
    customer_id, recency_days, frequency, monetary,
    r_score, f_score, m_score,
    (r_score + f_score + m_score)     AS rfm_score,
    CONCAT(r_score, f_score, m_score) AS rfm_string,
    CASE
        WHEN r_score = 4 AND f_score >= 3 AND m_score >= 3  THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3                  THEN 'Loyal Customers'
        WHEN r_score >= 3 AND f_score >= 2                  THEN 'Potential Loyalists'
        WHEN r_score = 4 AND f_score = 1                    THEN 'New Customers'
        WHEN r_score = 3 AND f_score = 1                    THEN 'Promising'
        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 THEN 'At Risk'
        WHEN r_score = 1 AND f_score >= 3 AND m_score >= 3  THEN 'Cannot Lose Them'
        WHEN r_score = 2 AND f_score <= 2 AND m_score <= 2  THEN 'About to Sleep'
        WHEN r_score = 1 AND f_score >= 2                   THEN 'Hibernating'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Need Attention'
        ELSE 'Lost'
    END AS segment
FROM v_rfm_scored;
```

**Segment scores — Average RFM per group (1–4 scale):**

<img width="1093" height="550" alt="viz3_rfm_heatmap" src="https://github.com/user-attachments/assets/b1aee83a-a8cd-4195-a40f-80beb4355e75" />

Champions average R=4, F=3.72, M=3.7. At Risk averages F=3.4 and M=3.38 — historically strong buyers — but R=1.78 flags them as lapsed.

---

### Q1 — Champions: Revenue Share & Profile

```sql
SELECT
    segment,
    COUNT(*)                                                       AS customers,
    ROUND(SUM(monetary), 2)                                       AS total_revenue,
    ROUND(SUM(monetary) * 100 / SUM(SUM(monetary)) OVER (), 2)   AS pct_of_total_revenue,
    ROUND(AVG(monetary), 2)                                       AS avg_lifetime_value,
    ROUND(AVG(frequency), 1)                                      AS avg_orders
FROM v_rfm_segments
WHERE segment IN ('Champions', 'Loyal Customers')
GROUP BY segment
ORDER BY total_revenue DESC;
```

**Finding:** Champions (1,008 customers) generate **£9,788,000 — 57.8% of total revenue**. Loyal Customers (1,093) add £3,304,700 (19.5%). Together, 2,101 customers — 35.9% of the base — drive 77.3% of all revenue.

---

### Q2 — At Risk Identification: Recency vs. Lifetime Value

```sql
SELECT segment, COUNT(*) AS customers,
       ROUND(AVG(recency_days), 1) AS avg_recency,
       ROUND(SUM(monetary), 2) AS total_revenue_at_risk
FROM v_rfm_segments
WHERE segment = 'At Risk'
ORDER BY monetary DESC;
```

**Finding:** 632 At Risk customers hold **£1,983,300** in lifetime revenue — 11.7% of total. These are high-frequency, high-spend customers who haven't purchased recently.

<img width="1093" height="600" alt="viz4_recency_vs_monetary" src="https://github.com/user-attachments/assets/f619cf06-69e8-4291-9739-1cdb0ade3be9" />

Champions (dark green) cluster bottom-left — recent and high-value. At Risk (pink/red) spread right — high historical spend, but increasingly lapsed.

---

### Q3 — Does the 80/20 Rule Hold?

```sql
WITH customer_quintiles AS (
    SELECT customer_id, monetary,
           NTILE(5) OVER (ORDER BY monetary ASC) AS quintile
    FROM v_rfm_segments
)
SELECT
    quintile,
    COUNT(*)                                                          AS customers,
    ROUND(SUM(monetary), 2)                                          AS group_revenue,
    ROUND(SUM(monetary) * 100 / SUM(SUM(monetary)) OVER (), 2)      AS pct_of_total_revenue,
    ROUND(SUM(SUM(monetary)) OVER (ORDER BY quintile DESC) * 100 /
          SUM(SUM(monetary)) OVER (), 2)                             AS cumulative_revenue_pct
FROM customer_quintiles
GROUP BY quintile
ORDER BY quintile DESC;
```

**Finding:** The 80% cumulative revenue line is crossed before the 20% customer mark — confirming the Pareto rule holds in this dataset.

<img width="1093" height="500" alt="viz5_pareto" src="https://github.com/user-attachments/assets/3693324a-1f10-4cf2-8784-0a310b4a2f2a" />

---

### Q5 — Average Order Value by Segment

```sql
SELECT
    segment,
    COUNT(*)                                   AS customers,
    ROUND(AVG(monetary / frequency), 2)       AS avg_order_value,
    RANK() OVER (ORDER BY AVG(monetary / frequency) DESC) AS aov_rank
FROM v_rfm_segments
GROUP BY segment
ORDER BY avg_order_value DESC;
```

**Finding:** Champions rank highest on AOV — high-value customers who buy frequently also spend more per order. About to Sleep and Need Attention rank lowest across both frequency and order size. Cannot Lose Them would theoretically rank highest but has 0 qualifying customers in this dataset.

---

<h2><a class="anchor" id="sample-outputs"></a>Sample Outputs</h2>

**Revenue by Segment — Champions vs. Everyone Else:**

<img width="1093" height="550" alt="viz2_revenue_by_segment" src="https://github.com/user-attachments/assets/89e2d41e-f340-4400-9a1b-638556a81b62" />

Champions (1,008 customers) drive **£9,788,000** — more revenue than all other 10 segments combined. Loyal Customers add £3,304,700 (19.5%). At Risk contributes £1,983,300 but that revenue is actively at risk of permanent loss.

---

<h2><a class="anchor" id="how-to-run-this-project"></a>How to Run This Project</h2>

1. Clone the repository:
```bash
git clone https://github.com/yourusername/rfm-analysis.git
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set up the MySQL database:
```sql
SOURCE 01_database_setup.sql;
```

4. Open and run the notebook — this handles cleaning, MySQL load, and all visualisations:
```bash
jupyter notebook RFM_Analysis.ipynb
```

5. (Optional) Run business queries directly in MySQL Workbench:
```sql
SOURCE 02_rfm_views.sql;
SOURCE 03_Business_Questions.sql;
```

---

<h2><a class="anchor" id="final-recommendations"></a>Final Recommendations</h2>

**Segment strategy — each group mapped to a concrete action:**

<img width="1093" height="460" alt="viz6_strategy_table" src="https://github.com/user-attachments/assets/7e930481-fde9-4e85-9692-987bd4096dc1" />

| Segment | Customers | % Revenue | Priority Action | Channel |
|---|---|---|---|---|
| Champions | 1,008 | 57.8% | Reward & Retain | Personalised email, exclusive events |
| Loyal Customers | 1,093 | 19.5% | Upsell & Cross-sell | Email, targeted ads |
| At Risk | 632 | 11.7% | Win Back | Email + personal call for top spenders |
| Potential Loyalists | 607 | 3.4% | Nurture to Loyalty | Email, push notifications |
| About to Sleep | 680 | 1.4% | Reactivate Now | Urgent email + SMS |
| Hibernating | 480 | 2.1% | Low-cost Re-engagement | Low-frequency email |
| Lost | 325 | 2.4% | Final Attempt or Suppress | Single win-back email |
| Need Attention | 807 | 1.2% | Re-engage | Email with discount |
| New Customers | 80 | 0.2% | Onboard & Engage | Welcome email sequence |
| Cannot Lose Them | 0 | — | Win Back Immediately | Personal phone call + email |
| Promising | 136 | 0.4% | Build Relationship | Email, retargeting ads |

_Cannot Lose Them has 0 qualifying customers in this dataset — the CASE criteria (low recency, high frequency, high monetary) produced no matches after cleaning. Monitor future cohorts for this segment._

**The single most urgent action:** Contact At Risk customers. 632 customers with strong historical spend (avg F=3.4, M=3.38) are drifting. A targeted win-back campaign before they cross into Hibernating is the highest-ROI lever available.

**For the next iteration:**
- Add a date parameter to the reference date rather than computing `MAX(invoicedate) + 1 DAY` inside a subquery — this makes the views reusable against live data
- Store the cleaning log (rows removed per step) as a separate summary table for auditability
- Validate segment boundary conditions between Promising and Potential Loyalists — a priority ordering in the CASE WHEN would resolve edge-case overlaps
- Add month-over-month cohort retention analysis — RFM is a snapshot; time-series by segment would strengthen the business narrative.
