# 📊 Olist E-Commerce Analytics: Logistics Margin Drag & Customer LTV Audit

**Business Context:** Olist, a major Brazilian e-commerce marketplace, experienced rapid GMV growth in H1 2018. However, executive leadership flagged significant margin erosion and an escalating spike in negative customer sentiment.  
**Objective:** Architect an end-to-end SQL diagnostic pipeline to isolate operational bottlenecks across merchant SLAs, freight unit economics, and cohort retention.

---

## 💡 Executive Summary
This project is an end-to-end data audit of Olist’s fulfillment and commercial architecture. By engineering memory-optimized SQL queries across 100K+ raw relational records, the analysis revealed that **margin erosion was heavily driven by toxic interstate freight pricing**, while **customer churn and 1-star review spikes were directly linked to merchant dispatch breaches** rather than pure carrier logistics delays.

**Tech Stack & Key Skills:**  
* **Data Engineering & Ingestion:** Python (`pandas`, `SQLAlchemy`, `mysql-connector-python`), Batch Chunk Processing.
* **Database & Querying:** MySQL 8.0+, Advanced Aggregations (`CASE WHEN`, `COALESCE`), Temporal Functions (`DATEDIFF`, `TIMESTAMPDIFF`).
* **Advanced SQL Frameworks:** Window Functions (`DENSE_RANK`, Cumulative GMV/Running Totals), CTEs, Dynamic Materialized Views (`v_clean_delivered_items`).
* **Performance Tuning:** Optimizer Execution Plan Enforcement (`STRAIGHT_JOIN` memory buffer bounding).
* **Business Analytics:** Unit Economics, Cohort Retention Curves, ABC/Pareto 80/20 Segmentation, Fulfillment SLA Diagnostics.

---

## 🔍 End-to-End Operational Bottlenecks

### 1. Logistics & Unit Economics (Margin Drag)
* **The "Toxic Freight" Crisis:** Discovered that in **~3.5% to 4%** of total delivered orders, freight fees equaled or exceeded product prices, burning **R$ 43,369** in subsidization during H1 2018.
* **Interstate Bottleneck:** **~60% to 64%** of all customer deliveries crossed state borders, where average fulfillment freight rose to **~R$ 24.1** compared to **~R$ 13.3** for local deliveries.

### 2. Seller SLA & Customer Sentiment (The 1-Star Spike)
* **Merchant Dispatch Breaches:** Proved that **1.17%** of deliveries suffered customer-facing breaches solely due to sellers missing their shipping limit dates, while carrier transit rescued **5.26%** of otherwise late dispatches.
* **Chronic Offenders:** Isolated the **Top 10** repeat offenders (volume >= 20 items) who routinely breached dispatch limits across Q1 and Q2, fueling an alarming surge in 1-star customer ratings.

### 3. Customer Retention (LTV) & Payment Friction
* **The One-and-Done Dilemma:** A staggering **97%** of Olist's customer base never returned for a repeat order, rendering customer acquisition economics unsustainable.
* **Payment Clearance Latency:** While Credit Cards captured dominant GMV share, Boleto transactions averaged **1.38 days** in clearance delays, triggering downstream fulfillment backlogs.

---

## ⚙️ Architecture & Engineering Optimization

### 🛠️ Automated Data Pipeline & Ingestion Architecture
* **The Challenge:** Standard GUI import wizards in MySQL Workbench faced network socket timeouts (`CR_SERVER_LOST 2006`) and RAM exhaustion when ingesting 100K+ relational records.
* **The Solution:** Developed a robust Python ETL pipeline script (`scripts/data_ingestion.py`) using `pandas` and `SQLAlchemy`.
* **Execution Blueprint:**
  - Implemented streaming chunked insertion (`chunksize=10000`) to bound client-side memory footprint.
  - Enforced schema typing and direct datetime casting (`DATETIME`) during load to prevent downstream query casting overhead.
  - Handled dependency sequences across primary/foreign key constraints during relational table creation.

### Query Memory Optimization (`STRAIGHT_JOIN`)
* **Problem:** Unindexed 4-table joins (`orders` -> `items` -> `sellers` -> `customers`) forced the MySQL optimizer to pick suboptimal driving tables, triggering buffer pool exhaustion and fatal connection terminations.
* **Solution:** Explicitly enforced the execution order via **`STRAIGHT_JOIN`**, driving scans strictly from filtered delivered orders.
* **Impact:** Reduced join complexity to $O(N)$ and eliminated virtual CTE memory bloat without modifying server-level buffer allocation.

### Dynamic View Pipelines
* Abstracted multi-table normalization joins and multilingual column mappings by compiling the `v_clean_delivered_items` View, delivering instantaneous aggregations for ABC/Pareto inventory metrics.

---

## 📂 Repository Directory Structure

```text
├── .gitignore                      # Prevents committing credentials, venv & raw dumps
├── README.md                       # Comprehensive business & technical audit documentation
├── scripts/
│   └── data_ingestion.py           # Automated Python ETL pipeline (Chunk ingestion)
├── Day-01-Delivery-Analysis/
│   ├── day1_queries.sql            # Macro baselines & review score correlations
│   └── outputs/                    # Exported audit CSVs (Steps 1-7)
├── Day-02-Seller-SLA/
│   ├── day2_queries.sql            # 4-Bucket SLA matrix & Top 10 Chronic Offenders
│   └── outputs/                    # Exported audit CSVs (Steps 1-5)
├── Day-03-Freight-Economics/
│   ├── day3_queries.sql            # Toxic freight corridor evaluation & margin leakage
│   └── outputs/                    # Exported audit CSVs (Steps 1-5)
├── Day-04-Payment-Retention/
│   ├── day4_queries.sql            # Payment latency & cohort retention analysis
│   └── outputs/                    # Exported audit CSVs (Steps 1-5)
└── Day-05-Product-Quality/
    ├── day5_queries.sql            # Pareto ABC categorization & density diagnostics
    └── outputs/                    # Exported audit CSVs (Steps 1-5)