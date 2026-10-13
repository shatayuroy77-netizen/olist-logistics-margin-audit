## Day 2 · Seller Dispatch Audit

**Stakeholder (simulated):** Camila Duarte, Head of Vendor Operations

**Her question:** Leadership wants a blanket penalty on all 3,000 sellers for late dispatch. Who is actually breaking the delivery promise?

### Short answer

1. **No blanket penalty.** Seller dispatch breaches were already falling: 10.76% of items in Q1 2018, 6.43% in Q2, with almost the same item volume.
2. **Most seller delays never reach the customer.** In Q2, 85% of late seller dispatches (1,236 of 1,456 items) still arrived on time because the courier made up the time. Only 0.97% of Q2 items were late because of the seller. The carrier caused about three times more (675 vs 220 items).
3. **Customers punish late arrival, not seller delay.** A late dispatch rescued by the courier scored 4.12 stars, almost the same as a clean delivery (4.23). When the customer got it late, the score fell to 2.29 to 2.61, and about half the reviews were 1-star.
4. **12 sellers drive 43% of the harm.** Ranked by late customers they caused, not by breach count, 12 sellers account for 95 of 220 seller-caused late deliveries in Q2. Only 7 of them had a bad Q1 record too, so a history-based rule would have missed five.

Full deck: `Day2_Seller_SLA_Deck.pdf`

### How it was measured

| Rule | Why |
|---|---|
| Counted per item, not per order | The seller deadline (`shipping_limit_date`) is set per item, and one order can hold items from several sellers. |
| Breach = handed to carrier after `shipping_limit_date` | The deadline has a real time of day, so the full timestamp is compared. |
| Late = `DATE(delivered) > DATE(estimated)` | Same rule as Day 1: the estimated date is stored at midnight. |
| Four buckets per item | Two checks (seller on time? customer on time?) separate a seller's delay from the harm it causes. |
| At least 20 items per seller | Removes sellers whose rate depends on a handful of orders. |
| Breach limit 10% for segments | Close to the Q1 platform average of 10.76%. Tested at 15% as well. |
| Action list: 3+ late customers in Q2 | One late customer can be an accident; three in a quarter is a pattern. |

### Data traps caught

- **Timestamps vs dates.** The first version compared full timestamps for delivery, which counted on-time deliveries as late. It showed 1.17% of Q2 items late because of the seller instead of 0.97%. The mismatch with Day 1 is how it was caught.
- **Ranking by breaches blames the wrong seller.** Seller `7c67e1` had the most breaches (66) but only 9 late customers. Seller `06a2c3` had 49 breaches and 27 late customers. The final ranking uses late customers.
- **Sellers who left look like they improved.** 14 sellers almost stopped selling in Q2 (under 5 items). They are labeled exited, not reformed.
- **Impossible dates.** 715 items (1.55%) show a carrier handover before order approval. Removing them moves the breach rate by 0.2 points at most (10.76% → 10.78% in Q1, 6.43% → 6.63% in Q2), so they are kept and the test is documented in Step 9.

### Limits

- Reviews belong to orders but are counted per item, so large orders weigh more, and orders with two sellers share one review.
- High-breach sellers get lower ratings (3.94 vs 4.19), but product type was not checked, so this is a link, not proof of cause.
- The four-bucket matrix covers Q2 only.
- The 20-item, 10% and 3-customer limits are judgment calls. 96 sellers had too little history to classify and are recommended for monitoring, not penalty.

### Files

```
Day-02-Seller-SLA/
├── README.md
├── 02_merchant_dispatch_audit.sql   # all queries, in order (Step 1 to Step 10)
├── Day2_Seller_SLA_Deck.pdf         # 12-slide deck for Camila
└── outputs/                         # 10 result CSVs, one per step (d02_01 to d02_10)
```
