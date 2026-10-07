# Olist Logistics & Margin Audit (MySQL)

A 5-day SQL audit of the public [Olist Brazilian e-commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (about 100K orders). Each day answers one question from a simulated stakeholder, with the SQL, the exported results and a short deck.

## Latest finding (Day 1)

Late deliveries hit **12.88% in Q1 2018** and fell to **4.17% in Q2**. A late order scored about 2 stars lower than an on-time one. The delay sits with the **carrier**: in Q1, late orders spent 30.80 days with the carrier against 9.50 for on-time orders, while sellers added only 1.55 days. Bahia, Pará and Ceará are still above 12% late.

[Day 1: queries, results and deck](./Day-01-Delivery-Analysis)

## Progress

| Day | Stakeholder | Question | Status |
|---|---|---|---|
| 1 | Marcos Silva, Head of Logistics | Is the delivery crisis real, and are the carriers to blame? | Done |
| 2 | Camila Duarte, Head of Vendor Operations | Should we really penalize 3,000 sellers? | In review |
| 3 | | When does freight cost more than the product? | Planned |
| 4 | | Payment methods and repeat customers | Planned |
| 5 | | Product categories and review scores | Planned |

Numbers for Days 2 to 5 are added here only after each day's queries are checked.

## Rules set on Day 1

- **Late** = `DATE(delivered) > DATE(estimated)`, comparing dates, not timestamps.
- **One review per order**, through the view `v_one_review`.
- **Impossible dates excluded**, such as a carrier pickup earlier than the order approval.
- **Same denominator** inside every comparison.

From Day 2 on, `order_items` and `order_payments` have several rows per order, so they need to be rolled up to order level before joining to `orders`.

## Technical notes

**Loading the data.** `scripts/data_ingestion.py` reads the nine Olist CSV files with pandas and writes them to MySQL through SQLAlchemy, 10,000 rows at a time. Each run replaces the tables, so the database can be rebuilt from scratch. Date columns are then converted to `DATETIME` in SQL, in Step 0 of the Day 1 script.

**Views.** `v_one_review` keeps the review-cleaning rule in one place, so every query uses the same logic. It is a regular view: it makes queries simpler, not faster.

## Tools

MySQL 8.0 · Python (pandas, SQLAlchemy) · CTEs · `CASE WHEN` · `DATEDIFF` · views

## Repo structure

    ├── scripts/
    │   └── data_ingestion.py
    ├── Day-01-Delivery-Analysis/            Done
    │   ├── README.md
    │   ├── 01_delivery_crisis_investigation.sql
    │   ├── Day1_Delivery_Audit_Deck.pdf
    │   └── outputs/                         11 result CSVs
    ├── Day-02-Seller-SLA/                   In review
    ├── Day-03-Freight-Economics/            Planned
    ├── Day-04-Payment-Retention/            Planned
    └── Day-05-Product-Quality/              Planned

---

Shatayu Roy · [LinkedIn](https://www.linkedin.com/in/shatayu-roy/)
