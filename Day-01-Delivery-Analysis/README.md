# Day 1 · Delivery Delay Audit

**Stakeholder (simulated):** Marcos Silva, Head of Logistics

**His question:** Is the late-delivery crisis real, and are the carriers to blame?

## Short answer

1. **The crisis was real, but it is already easing.** 12.88% of delivered orders bought in Q1 2018 arrived late. In Q2 that fell to 4.17%, and delivery got about 5 days faster.
2. **Reviews moved with the delays.** A late order scored 2.01 stars on average in Q1, against 4.22 for an on-time order.
3. **The delay sits with the carrier, not the seller.** In Q1, late orders spent 30.80 days with the carrier, against 9.50 days for on-time orders. Seller handling added only 1.55 days. Q2 shows the same pattern.
4. **Three states still need attention:** Bahia, Pará and Ceará are still above 12% late in Q2.

Full deck: [Day1_Delivery_Audit_Deck.pdf](./Day1_Delivery_Audit_Deck.pdf)

## How it was measured

| Rule | Why |
|---|---|
| Late = `DATE(delivered) > DATE(estimated)` | The estimated date is stored at midnight, so comparing full timestamps would flag same-day deliveries as late. |
| One review per order (`v_one_review`) | Some orders have more than one review; without this, joins count those orders twice. |
| 321 orders excluded from timing analysis | Their carrier pickup date is earlier than their approval date, which is impossible. |
| Same denominator for every rate | So Q1 vs Q2 and state vs state percentages are comparable. |

**Seller days** = order approved → handed to carrier.

**Carrier days** = handed to carrier → delivered to customer.

## Limits

- The data has no carrier names, so the analysis shows that the carrier leg is slow, not which carrier.
- Distance is not separated from carrier quality; longer routes may explain part of the gap.
- Orders without a review are left out of score and state analysis.
- The analysis covers January to June 2018, so "recovering" rests on one quarter of improvement.

## Files

    Day-01-Delivery-Analysis/
    ├── README.md
    ├── 01_delivery_crisis_investigation.sql   # all queries, in order (Step 0 to Step 8)
    ├── Day1_Delivery_Audit_Deck.pdf           # 12-slide deck for Marcos
    └── outputs/                               # 11 result CSVs, one per step
