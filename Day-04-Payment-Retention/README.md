## Day 4 · Payment Speed & Repeat Customers

**Stakeholder (simulated):** Lucas Rocha, Head of Growth & FinTech

**His question:** Marketing wants another R$ 2M for customer acquisition. Boleto orders take over a day just to be approved, and it looks like almost nobody buys a second time. Are we pouring acquisition money into a leaky bucket?

### Short answer

1. **Boleto is slow.** In H1 2018 a Boleto order waited 33.15 hours on average for approval, and 57.13% waited more than a day. For credit card it was 4.65 hours and 7.04%. Boleto is 17.05% of the money paid (7,679 delivered orders), so the delay is not a side issue.
2. **But the delay does not lose more orders.** 0.66% of Boleto orders were canceled or unavailable, against 0.77% for credit card.
3. **The bucket does leak.** Across the full data, 97.00% of customers bought only once, and they bring 94.40% of the money. Customers who come back spend more: R$ 291.03 with two orders and R$ 506.79 with three or more, against R$ 160.76 for a one-time buyer.
4. **Boleto is not the leak.** Customers whose first order was paid by Boleto came back at 2.99%, exactly the same as credit card customers (2.99%). Faster Boleto approval would not bring more customers back.

Full deck: `Day4_Payment_Retention_Deck.pdf`

### Recommendation

1. **Don't put the whole R$ 2M into new customers.** With 97% buying once, most of them will not return. Move part of the budget to getting first-time buyers to order again, and judge it by the repeat rate, which is about 3% today.
2. **Don't treat faster Boleto as a retention fix.** It may be worth doing for other reasons, but repeat buying is the same whether the first order was Boleto or card.
3. **Ask Marketing what one new customer costs (CAC).** A one-time buyer pays R$ 160.76 on average, and that is revenue including freight, not profit. If CAC is close to that, every new one-time buyer loses money. That number decides how much of the R$ 2M makes sense.

### How it was measured

| Rule | Why |
|---|---|
| Steps 1-3: Jan-Jun 2018, per order | Same period as Days 1-3. Payments belong to orders. |
| Steps 4-6: full data (Sep 2016-Aug 2018), per customer | Six months is too short to see who comes back. |
| Delivered orders only, except Step 3 | Step 3 is about the orders that did not make it. |
| Customers counted by `customer_unique_id` | Olist creates a new `customer_id` for every order, so `customer_id` can't show repeat buyers. |
| One row per order and payment type before joining | An order with three voucher rows would otherwise count three times. |
| Lost = canceled or unavailable | Shipped, invoiced and processing orders were still on the way when the data ends. |
| Over 24h = more than 1,440 minutes from purchase to approval | The average is pulled up by a few very late approvals; this share is not. |
| First payment = the method with the most money in the first delivered order | Some orders mix card and voucher. |
| `payment_value` includes freight | So totals here are higher than Day 3 GMV, which was item price only. |

### Data traps caught

- **Payment rows are not orders.** The first draft counted rows in `order_payments`. One order can have several voucher rows, so voucher showed R$ 65.70 per payment. Counted per order (H1 2018, delivered) it is R$ 98.19.
- **Joining before averaging.** Joining orders to every payment row made `AVG` count multi-payment orders more than once. Payments are now cut to one row per order and type first.
- **`customer_id` is not a customer.** It changes with every order. Repeat buying only shows up with `customer_unique_id`.
- **Not delivered is not lost.** The first version of Step 3 counted every non-delivered order as lost, including orders that were still being shipped. Only canceled and unavailable count now.
- **An off-question step was dropped.** A credit card installment breakdown was interesting but did not test any of Lucas's claims, so it was removed.
- **Step 6 never finished in MySQL.** The id columns are TEXT with no keys. Indexes on the join columns (made in Day 3, Step 0) and two indexed temporary tables brought it down to seconds.
- **One delivered order has no payment row,** so Step 5 has one single buyer fewer than Step 4 (90,556 vs 90,557).

### Limits

- The data has no acquisition cost, so "wasted money" can't be measured directly.
- Unpaid Boletos are probably not in the dataset: almost every Boleto order is approved. Step 3 can't see customers who gave up before paying.
- Customers who first bought near the end of the data had little time to come back, so the real repeat rate is a bit higher. This affects every payment method the same way.
- Step 6 shows that Boleto and repeat buying don't go together. It does not show why customers leave.
- Totals include freight.

### Files

```
Day-04-Payment-Retention/
├── README.md
├── 04_payments_retention_audit.sql   # all queries, in order (Step 1 to Step 6)
├── Day4_Payment_Retention_Deck.pdf   # deck for Lucas
└── outputs/                          # 6 result CSVs, one per step (d04_01 to d04_06)
```
