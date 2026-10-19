# Olist Logistics & Margin Audit (MySQL)

A 5-day SQL audit of the public [Olist Brazilian e-commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (about 100K orders). Each day answers one question from a simulated stakeholder, with the SQL, the exported results and a short deck.

## Latest finding (Day 2)

Day 2 analyses 46,219 delivered order items from January to June 2018. Seller dispatch breaches fell from **10.76% in Q1** to **6.43% in Q2**. Most seller delays never reached the customer: in Q2, **85% of late dispatches still arrived on time**, and only 0.97% of items were late because of the seller. Customers punished late arrival, not seller delay: a rescued late dispatch scored 4.12 stars against 4.23 for a clean delivery. Instead of a blanket penalty, **12 sellers account for 43%** of seller-caused late deliveries.

[Day 2: queries, results and deck](Day-02-Seller-SLA/) · [Day 1: queries, results and deck](Day-01-Delivery-Analysis/)

## Progress

| Day | Stakeholder | Question | Status |
|---|---|---|---|
| 1 | Marcos Silva, Head of Logistics | Is the delivery crisis real, and are the carriers to blame? | Done |
| 2 | Camila Duarte, Head of Vendor Operations | Should we really penalize 3,000 sellers? | Done |
| 3 | Henrique Silva, Chief Financial Officer | Is interstate freight cannibalizing marketplace margins? | Planned |
| 4 | | Payment methods and repeat customers | Planned |
| 5 | | Product categories and review scores | Planned |

Numbers for Days 3 to 5 are added here only after each day's queries are checked.

## Rules across all days

Set on Day 1:

- **Late** = `DATE(delivered) > DATE(estimated)`, comparing dates, not timestamps.
- **One review per order**, through the view `v_one_review`.
- **Impossible dates are checked**, such as a carrier pickup earlier than the order approval.
- **Same denominator** inside every comparison.

Added on Day 2:

- **Items vs orders.** `order_items` has several rows per order. Questions about orders roll it up to order level before joining to `orders`. Questions about sellers stay at item level, because each item has its own seller and its own deadline (`shipping_limit_date`). Day 2 is seller-level, so it counts items.
- **At least 20 items** for seller rankings, so a few orders cannot decide a seller's rate.

## Technical notes

**Loading the data.** `scripts/data_ingestion.py` reads the nine Olist CSV files with pandas and writes them to MySQL through SQLAlchemy, 10,000 rows at a time. Each run replaces the tables, so the database can be rebuilt from scratch. Date columns are then converted to `DATETIME` in SQL, in Step 0 of the Day 1 script.

**Views.** `v_one_review` (Day 1) keeps the review-cleaning rule in one place. `v_seller_quarters` (Day 2) holds each seller's Q1 and Q2 totals, so the segment, review and action-list steps reuse one calculation. Both are regular views: they make queries simpler, not faster.

## Tools

MySQL 8.0 · Python (pandas, SQLAlchemy) · `CASE WHEN` · `DATEDIFF` · window functions (DENSE_RANK, SUM OVER) · views

## Repo structure

```
├── scripts/
│   └── data_ingestion.py
├── Day-01-Delivery-Analysis/            Done
│   ├── README.md
│   ├── 01_delivery_crisis_investigation.sql
│   ├── Day1_Delivery_Audit_Deck.pdf
│   └── outputs/                         11 result CSVs
├── Day-02-Seller-SLA/                   Done
│   ├── README.md
│   ├── 02_merchant_dispatch_audit.sql
│   ├── Day2_Seller_SLA_Deck.pdf
│   └── outputs/                         10 result CSVs
├── Day-03-Freight-Economics/            Planned
├── Day-04-Payment-Retention/            Planned
└── Day-05-Product-Quality/              Planned
```

---

Shatayu Roy · [LinkedIn](https://www.linkedin.com/in/shatayu-roy/)
