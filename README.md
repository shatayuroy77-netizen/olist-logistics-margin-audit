# Olist Logistics & Margin Audit (MySQL)

A 5-day SQL audit of the public Olist Brazilian e-commerce dataset (about 100K orders). Each day answers one question from a simulated stakeholder, with the SQL, the exported results and a short deck.

## Latest finding (Day 3)

Day 3 analyses freight on 46,219 delivered order items from January to June 2018. Freight is not outpacing sales: freight per R$ 100 of goods fell from R$ 17.02 in Q1 to R$ 16.62 in Q2. Customers pay it: in 99.76% of 40,273 orders, the payment equals item price plus freight. The pressure is interstate, where items pay R$ 18.92 per R$ 100 against R$ 12.28 locally. The heaviest burden falls on the Northeast, where customers buy almost nothing from local sellers (Bahia 0.46%) and pay R$ 21 to R$ 28 per R$ 100.

[Day 3: queries, results and deck](Day-03-Freight-Economics/) · [Day 2: queries, results and deck](Day-02-Seller-SLA/) · [Day 1: queries, results and deck](Day-01-Delivery-Analysis/)

## Progress

| Day | Stakeholder | Question | Status |
|---|---|---|---|
| 1 | Marcos Silva, Head of Logistics | Is the delivery crisis real, and are the carriers to blame? | Done |
| 2 | Camila Duarte, Head of Vendor Operations | Should we really penalize 3,000 sellers? | Done |
| 3 | Henrique Silva, Chief Financial Officer | Are we bleeding cash on interstate freight? | Done |
| 4 | | Payment methods and repeat customers | Planned |
| 5 | | Product categories and review scores | Planned |

Numbers for Days 4 and 5 are added here only after each day's queries are checked.

## Rules across all days

Set on Day 1:

- Late = `DATE(delivered) > DATE(estimated)`, comparing dates, not timestamps.
- One review per order, through the view `v_one_review`.
- Impossible dates are checked, such as a carrier pickup earlier than the order approval.
- Same denominator inside every comparison.

Added on Day 2:

- `order_items` has several rows per order. Questions about orders roll it up to order level before joining to `orders`. Questions about sellers stay at item level, because each item has its own seller and its own deadline (`shipping_limit_date`). Day 2 is seller-level, so it counts items.
- Seller rankings use at least 20 items, so a few orders cannot decide a seller's rate.

Added on Day 3:

- Groups with different item prices are compared on freight per R$ 100 of goods, not average freight alone.
- `freight_value` is what the customer is charged. Cost or margin claims need a cost column, which this dataset does not have.
- Two tables with several rows per order (`order_items`, `order_payments`) are each totalled per order before they are joined.

## Technical notes

**Loading the data.** `scripts/data_ingestion.py` reads the nine Olist CSV files with pandas and writes them to MySQL through SQLAlchemy, 10,000 rows at a time. Each run replaces the tables, so the database can be rebuilt from scratch. Date columns are then converted to DATETIME in SQL, in Step 0 of the Day 1 script.

**Views.** `v_one_review` (Day 1) keeps the review-cleaning rule in one place. `v_seller_quarters` (Day 2) holds each seller's Q1 and Q2 totals, so the segment, review and action-list steps reuse one calculation. Both are regular views: they make queries simpler, not faster.

**STRAIGHT_JOIN (Day 3).** The four-table joins (orders, items, sellers, customers) crashed MySQL twice by exhausting the buffer pool. Normal joins and CTEs did not help. `STRAIGHT_JOIN` makes MySQL start from the filtered `orders` table, which fixed it.

## Tools

MySQL 8.0 · Python (pandas, SQLAlchemy) · CASE WHEN · DATEDIFF · window functions (DENSE_RANK, SUM OVER) · views · CTEs · STRAIGHT_JOIN

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
├── Day-03-Freight-Economics/            Done
│   ├── README.md
│   ├── 03_logistics_cost_and_corridor_audit.sql
│   ├── Day3_Freight_Corridor_Deck.pdf
│   └── outputs/                         8 result CSVs
├── Day-04-Payment-Retention/            Planned
└── Day-05-Product-Quality/              Planned
```

---

Shatayu Roy · [LinkedIn](https://www.linkedin.com/in/shatayu-roy/)
