# Olist Logistics & Margin Audit (MySQL)

A 5-day SQL audit of the public Olist Brazilian e-commerce dataset (about 100K orders). Each day answers one question from a simulated stakeholder, with the SQL, the exported results and a short deck.

## Latest finding (Day 4)

Day 4 checks whether more acquisition money would leak away. Boleto is slow: in H1 2018, 57.13% of Boleto orders waited more than a day for approval, against 7.04% for credit card. But it does not lose more orders: 0.66% of Boleto orders were canceled or unavailable, against 0.77% for card. The bucket does leak: across the full data, 97% of customers bought only once, and they brought 94.40% of the money. Boleto is not the cause: customers whose first order was paid by Boleto came back at 2.99%, the same as card customers.

[Day 4: queries, results and deck](Day-04-Payment-Retention/) · [Day 3: queries, results and deck](Day-03-Freight-Economics/) · [Day 2: queries, results and deck](Day-02-Seller-SLA/) · [Day 1: queries, results and deck](Day-01-Delivery-Analysis/)

## Progress

| Day | Stakeholder | Question | Status |
|---|---|---|---|
| 1 | Marcos Silva, Head of Logistics | Is the delivery crisis real, and are the carriers to blame? | Done |
| 2 | Camila Duarte, Head of Vendor Operations | Should we really penalize 3,000 sellers? | Done |
| 3 | Henrique Silva, Chief Financial Officer | Are we bleeding cash on interstate freight? | Done |
| 4 | Lucas Rocha, Head of Growth & FinTech | Are we bleeding acquisition money into a leaky bucket? | Done |
| 5 | Marcelo Gomes, Head of Growth | Should ticket size decide where retention money goes? | Planned |

Numbers for Day 5 are added here only after its queries are checked.

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

Added on Day 4:

- Customers are counted by `customer_unique_id`. Olist gives a new `customer_id` to every order, so `customer_id` can't show repeat buyers.
- `order_payments` is cut to one row per order and payment type before joining, so an order paid with several vouchers is not counted several times.
- A lost order means canceled or unavailable. Shipped, invoiced and processing orders were still on the way when the data ends.
- `payment_value` includes freight, so payment totals are higher than GMV, which is item price only.
- Repeat buying is measured on the full data (Sep 2016 to Aug 2018). Six months is too short to see who comes back.

## Technical notes

**Loading the data.** `scripts/data_ingestion.py` reads the nine Olist CSV files with pandas and writes them to MySQL through SQLAlchemy, 10,000 rows at a time. Each run replaces the tables, so the database can be rebuilt from scratch. Date columns are then converted to DATETIME in SQL, in Step 0 of the Day 1 script.

**Views.** `v_one_review` (Day 1) keeps the review-cleaning rule in one place. `v_seller_quarters` (Day 2) holds each seller's Q1 and Q2 totals, so the segment, review and action-list steps reuse one calculation. Both are regular views: they make queries simpler, not faster.

**Indexes (Days 3 and 4).** The tables were loaded with pandas, so the id columns are TEXT with no keys and no indexes. On Day 3 the four-table joins (orders, items, sellers, customers) crashed MySQL twice, and `STRAIGHT_JOIN` was used to get through. On Day 4 a repeat-buying step never finished, which showed the real cause: no indexes. Indexes on the join columns are now created once, in Step 0 of the Day 3 script, and Day 3 is back on normal joins. TEXT columns need a prefix length, and every Olist id is 32 characters, so the indexes use `order_id(32)` and the like. Day 4's repeat-buying step also uses two indexed temporary tables, and it now runs in seconds.

## Tools

MySQL 8.0 · Python (pandas, SQLAlchemy) · CASE WHEN · DATEDIFF · window functions (DENSE_RANK, SUM OVER, ROW_NUMBER, COUNT OVER) · views · CTEs · temporary tables · indexes

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
├── Day-04-Payment-Retention/            Done
│   ├── README.md
│   ├── 04_payments_retention_audit.sql
│   ├── Day4_Payment_Retention_Deck.pdf
│   └── outputs/                         6 result CSVs
└── Day-05-Product-Quality/              Planned
```

---

Shatayu Roy · [LinkedIn](https://www.linkedin.com/in/shatayu-roy/)
