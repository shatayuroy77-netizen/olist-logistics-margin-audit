## Day 3 · Freight Charges & Interstate Corridors

**Stakeholder (simulated):** Henrique Silva, Chief Financial Officer

**His question:** Freight is running at R$ 466K per quarter, and customers complain that delivery fees exceed product prices. Are we bleeding cash on interstate logistics?

### Short answer

1. **Freight is not outpacing sales.** From Q1 to Q2 2018, GMV grew 3.8% and freight grew 1.4%. Freight per R$ 100 of goods fell from R$ 17.02 to R$ 16.62. The R$ 466K figure is correct (Q2: R$ 466,475), but it is stable.
2. **Customers pay the freight.** In 99.76% of 40,273 delivered orders, the customer paid exactly the item price plus freight. The other 96 orders paid more, never less. The data has no carrier cost, so whether Olist loses money on the carrier side cannot be answered here.
3. **The pressure is interstate.** About 60-65% of items cross a state border and carry about 75% of all freight. In Q2, interstate items paid R$ 18.92 per R$ 100 of goods against R$ 12.28 for local items. 90% of items where freight was equal to or higher than the price were interstate. These items are a complaint problem, not a cash problem: their freight was R$ 43K, 4.7% of H1 freight.
4. **The money sits on a few routes.** The top 10 interstate routes carry 52% of interstate freight. SP to RJ and SP to MG alone carry 22%, at a normal R$ 19 per R$ 100.
5. **The heaviest burden falls where there are no local sellers.** SP customers buy 77% of their items from SP sellers and pay R$ 13.68 per R$ 100. Northeast customers buy almost nothing locally (Bahia 0.46%, Ceará 0.71%, Paraíba, Alagoas and Sergipe 0%) and pay R$ 21 to R$ 28.

Full deck: `Day3_Freight_Corridor_Deck.pdf`

### Recommendation

1. **Get carrier invoices first.** The dataset has no carrier cost, so invoices are the only way to answer the margin question and to see where rates are too high.
2. **Recruit sellers in the Northeast, starting with Bahia.** Bahia has the largest Northeast demand (1,510 items in H1), and only 7 came from local sellers. Local items pay R$ 12.28 per R$ 100 against R$ 18.92 for interstate (Q2). A regional warehouse makes sense only once volume grows. The North (AM, AP, AC, RR, under 70 items each) is too small for now.
3. **Then negotiate the busiest routes.** If the invoices show room, start with SP to RJ and SP to MG, which carry 22% of interstate freight. Every R$ 1 cut per item there is worth about R$ 7.4K a half-year. Finance decides whether the saving goes to customers or stays with Olist.

### How it was measured

| Rule | Why |
|---|---|
| Counted per item (Step 8 per order) | Each item has its own seller and seller state, so a route belongs to an item. Payments belong to orders, so Step 8 is per order. Orders hold about 1.14 items on average. |
| Jan-Jun 2018, delivered orders only | The CFO asked about H1. Same period as Day 2. Cancelled orders never shipped. |
| Interstate = `seller_state <> customer_state` | State-level, so neighbouring states also count as interstate. |
| Freight burden = freight ÷ item price × 100 | Average freight alone rises when pricier items ship. |
| Freight ≥ item price | No item has freight exactly equal to the price, so ≥ and > give the same count. |
| At least 20 items per route | Same rule as Day 2. |
| Payment match within R$ 0.05 | Allows for rounding. |

### Data traps caught

- **"Margin" cannot be measured.** The first draft called freight Olist's cost and measured "margin drag". `freight_value` is what the customer is charged, and there is no carrier cost column. Step 8 was added to prove who pays.
- **Average freight hides item price.** Interstate average freight rose 11% from Q1 to Q2 (R$ 22.84 to R$ 25.41), but per R$ 100 of goods it barely moved (18.69 to 18.92). Pricier items shipped; rates did not rise.
- **Two tables with several rows per order.** Joining `order_items` directly to `order_payments` multiplies rows and inflates totals. Both are totalled per order first.
- **A first measure of seller supply mixed two things.** It compared items sold by a state's sellers with items bought by its customers, but those sellers may ship anywhere. It was replaced by local purchase share, which counts one thing.
- **Zero freight.** 368 items (0.8%) had no freight, likely free-shipping offers. Who paid the carrier for them is not in the data.

### Limits

- Carrier cost is not in the data, so it is unknown whether Olist loses money on carriers.
- Lost sales cannot be measured: the data holds only orders that were placed.
- Freight above price is counted per item. Per order it would be slightly lower, because other items in the same order raise the order total.
- Routes are state to state, not distance. The Northeast is both far from São Paulo and short of local sellers. Distance was not measured here, so the two effects are not separated; the Olist geolocation table could do this as a next step.
- Two quarters only: a direction, not a long trend.
- The 96 orders that paid more are probably instalment interest, but the data does not say.
- H1 2018 only.

### Files

```
Day-03-Freight-Economics/
├── README.md
├── 03_logistics_cost_and_corridor_audit.sql   # all queries, in order (Step 1 to Step 8)
├── Day3_Freight_Corridor_Deck.pdf             # 12-slide deck for Henrique
└── outputs/                                   # 8 result CSVs, one per step (d03_01 to d03_08)
```
