## Day 5 · Category Value & Repeat Buying

**Stakeholder (simulated):** Marcelo Gomes, Head of Growth

**His question:** The R$ 2M retention budget is planned for Electronics and Office Furniture because of their high GMV ticket size. Can we greenlight the spend before Monday's board meeting?

### Short answer

1. **Not on this evidence.** Neither category is a strong retention bet: their buyers come back less often than the average customer.
2. **Electronics is not high-ticket.** An Electronics item sold for R$ 50.88 on average in H1 2018, against R$ 119.25 for all items. Office Furniture was slightly above average (R$ 158.68). The truly expensive category is computers (R$ 816.40), a separate category in Olist.
3. **Together they are a small part of sales.** Office Furniture is 2.19% of H1 GMV and Electronics 1.45%, 3.64% combined.
4. **Their buyers rarely come back.** Across all categories, 3.00% of customers place a second order (the same figure as Day 4). Customers whose first order was Office Furniture come back 2.04% of the time, Electronics 1.71%, computers 0.57%. Home appliances buyers come back 8.61%, fashion bags 5.61%.
5. **Each category has its own problem.** Office Furniture gets a 1-star review on 15.94% of orders that arrived on time, about twice the average of 7.29%, which points to the product or seller, not delivery. Electronics reviews are fine (5.79%), but its freight is the heaviest of any category: R$ 32.70 per R$ 100 of goods against R$ 16.81 overall, because cheap items still pay a full delivery charge.

Full deck: `Day5_Category_Retention_Deck.pdf`

### Recommendation

1. **Do not commit R$ 2M to Electronics and Office Furniture.** Spread over the 3,687 customers who started with them, it would be about R$ 542 per customer, for buyers whose average item costs R$ 51 to R$ 159 and who come back about 2 times in 100.
2. **Run a small pilot where customers already return.** Home appliances (8.61% come back) and fashion bags (5.61%, and only 3.34% 1-star reviews) are the strongest candidates. Send offers to part of their buyers and keep a similar group without offers. Success measure: the repeat rate of the offer group against the other group. Release more budget only if the gap is real.
3. **Fix Office Furniture before spending on it.** Find which sellers and products drive the 1-star reviews on on-time orders, using the Day 2 seller method. Success measure: on-time 1-star rate down toward the 7.29% average.
4. **For Electronics, look at freight, not retention.** Freight is a third of the item price. A free-shipping threshold or bundled shipping could be tested. Success measure: freight per R$ 100 and repeat rate for Electronics buyers.

### How it was measured

| Rule | Why |
|---|---|
| Steps 1, 3, 4: Jan-Jun 2018, delivered orders only | Same period as Days 1-4. Step 1 totals 46,219 items, the same as Day 3. |
| Step 2: full history, per customer | Few people buy twice within six months. Same rule as Day 4, and the overall repeat rate matches Day 4 (3.00%). |
| Customers by `customer_unique_id` | A new `customer_id` is created for every order. Same as Day 4. |
| Step 2b: only customers whose first order was before March 2018 | The data ends in late August 2018, so each of them had at least six months to come back. |
| A customer's category = category of their first order | Groups customers by how they started. A first order with mixed categories takes the category of its priciest item. |
| "Came back" = any second delivered order | Retention means returning to Olist, whatever they buy. Coming back for the same category can only be lower, so the rates for Electronics and Office Furniture are an upper limit. |
| Average price = total GMV ÷ total items | Not an average of category averages, which would let small expensive categories pull it up. |
| 1-star rate on on-time orders only | Removes late delivery as a reason for a bad review. Late = `DATE(delivered) > DATE(estimated)`, same as Day 1. |
| One review per order (`v_one_review`), duplicate rows removed before the join | A three-chair order has three item rows but one review. |
| Freight per R$ 100 of goods | Same measure as Day 3. Average freight alone rises with pricier items. |
| At least 100 items, reviews or customers per category | Rates on a handful of orders jump around. |

### Data traps caught

- **The first draft used the whole 2016-2018 history.** Numbers would not have matched Days 1-4 side by side. All sales, review and freight steps were limited to Jan-Jun 2018.
- **Reviews were counted more than once.** The first draft joined reviews at item level, so an order with three items counted its review three times. The table did not agree with itself: Office Furniture showed 267 one-star reviews out of 1,133, which is 23.6%, but the rate column said 17.60%. Removing duplicate order rows before the join fixed it.
- **The first repeat measure gave credit to the wrong category.** It counted every order of a repeat customer, so a buyer who started with Electronics and came back for bedding counted as an Electronics repeat order. It was replaced by a per-customer measure that counts one thing: did a customer who started with category X order again.
- **Shared reviews were checked, not assumed.** A review belongs to an order, so an order with two categories counts in both. This happens in 322 of 40,273 orders (0.80%), too few to move the rates.
- **A Pareto/ABC split was dropped.** It showed revenue concentration but did not answer the question. The two categories' rank (14th and 20th by GMV) is enough.

### Limits

- There is no margin, cost or marketing spend in the data. GMV is not profit, so the analysis can say the evidence for the spend is weak, not that it would lose money.
- Repeat rates show past behaviour without offers. They do not show how customers would respond to a coupon; the pilot is how to find out.
- Customers who first bought near the end of the data had less time to come back. Step 2b keeps only those with at least six months: every rate rises, but Electronics (2.79%) and Office Furniture (2.71%) still sit below the average (3.98%), and home appliances stays on top (9.09%). The average here is derived from the Step 2b output (2,165 of 54,350 customers).
- A review covers the whole order, so in a mixed order it cannot be split between items.
- Computers had only 52 items in H1 2018, below the 100-item rule, so its review and freight figures appear only in the scorecard and are a hint, not a finding.
- Categories are Olist's own labels. "Electronics" in the brief may mean computers; both are shown.

### Files

```
Day-05-Category-Retention/
├── README.md
├── 05_category_value_and_repeat_buying.sql   # all queries, in order (Step 0 to Step 5, with 2b)
├── Day5_Category_Retention_Deck.pdf          # 10-slide deck for Marcelo
└── outputs/                                  # 7 result CSVs (d05_01 to d05_05, with 02b, 03a and 03b)
```
