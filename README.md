# Olist-Delivery-Sales-Performance-Analysis
> **Where is a Brazilian e-commerce marketplace losing customer satisfaction, and what should operations fix first?**
An end-to-end business analytics project on 96,203 delivered marketplace orders (Jan 2017 – Aug 2018), built with SQL, advanced Excel and Power BI. It goes from raw relational data to a prioritised, quantified recommendation.
Tools: SQL (SQLite) · Excel · Power BI (DAX) · Python (data loading only)
![Dashboard](dashboard/dashboard_preview.png)
<!-- After you build your Power BI report, add your own screenshots here, e.g.
![Power BI - Executive Summary](dashboard/powerbi_page1_executive_summary.png)
---
Table of contents
Business problem
Key findings
Recommendations
Approach
Repository structure
Data
Metric definitions
How to reproduce
Skills demonstrated
Limitations
Next steps
About me
---
1. Business problem
Olist connects small sellers to customers across Brazil. Leadership sees an average review of 4.16 / 5 and an 8.1% late-delivery rate, and wants to know:
How much does a late delivery really cost in customer satisfaction?
Is lateness spread evenly, or concentrated in particular regions, sellers or periods?
With limited operational capacity, what should be fixed first, and what is it worth?
2. Key findings
#	Finding	Evidence
1	Late deliveries wreck reviews	Late orders average 2.57★ vs 4.30★ on time. 54% of late orders get a 1–2★ review vs 9% on time (≈6x).
2	The damage is a cliff, not a slope	Orders 1–3 days late still average 3.77★; at 4–7 days late it falls to 2.32★; beyond 8 days it sits at ~1.7★.
3	Lateness is concentrated	Rio de Janeiro, Bahia and Ceará hold 66% of all "excess" late orders; Rio alone holds 46% (13.5% late vs ~6% in São Paulo).
4	Distance matters	Cross-state orders are late 9.0% of the time and take 15.0 days; same-state: 6.0% and 7.9 days.
5	Peak demand breaks delivery	Black Friday month (Nov 2017) was 7.6% of orders but 13.3% of all late orders; the late rate hit 20–23% for six straight days.
6	Revenue is concentrated in a few sellers	The top 10% of sellers generate 67% of GMV. The 20 sellers with the most late orders account for 24% of all late orders.
7	Honest caveat: repeat purchase is a weak lever	Only ~3% of customers ever reorder. First-order-late customers repeat 28% less (2.16% vs 2.98%, p = 0.002), but the revenue effect is small (about R$530 in the 50% scenario). The prize is reputation, not repeat sales.
3. Recommendations
#	Action	Rationale	Estimated impact
1	Last-mile / carrier review in RJ, BA and CE first	66% of excess lateness	Halving it avoids ≈474 late orders and ≈212 negative reviews; national late rate 8.13% → 7.64%
2	Seller watchlist: SLA improvement plans for the 5 worst high-volume sellers	Concentrated and controllable; several are also high-revenue sellers	≈214 excess late orders across the 5
3	Peak-season playbook (capacity cut-offs, carrier pre-booking, ETA padding in risky lanes)	Black Friday: 13% of late orders from 7.6% of volume	Protects the highest-traffic cohort
4	A/B test region-aware delivery promises	Average promise is 23.6 days vs 12.5 actual, so lateness is a tail problem in specific lanes	Hypothesis to test, not a certainty
Recommendations 3 and 4 are hypotheses: the data shows where the problem is, not why. Full write-up: docs/Case_Study.md.
4. Approach
Step	What I did	Tool
Model	Joined 8 tables into reusable views at order and item grain (handled multi-item orders and multiple reviews per order)	SQL
Define	Set metric definitions; excluded undelivered orders and the sparse periods (2016, Sep–Oct 2018)	SQL
Analyse	Trend, review impact, repeat-purchase cohort, state / category / seller scorecards, Black Friday stress test	SQL (`LAG`, `RANK`, `NTILE`, `ROW_NUMBER`, running `SUM() OVER`)
Prioritise	Built an excess late orders metric to rank where to act, not just who is worst by rate	SQL + Excel
Quantify	What-if model with adjustable assumptions and a sensitivity table	Excel
Communicate	Executive dashboard and one-page recommendation	Power BI
5. Repository structure
```
olist-delivery-sales-analysis/
├── README.md
├── run_all.sh                 # rebuild everything from the raw CSVs
├── requirements.txt
├── sql/
│   ├── 00_load_data.py        # load the 8 CSVs into SQLite (olist.db)
│   ├── 01_views.sql           # v_order_value, v_order_facts, v_item_facts
│   ├── 02_analysis.sql        # KPIs, trend, reviews, cohort, state/category/seller analysis
│   ├── 03_prioritisation.sql  # excess-late ranking, concentration, Black Friday
│   └── run_sql.py             # runs a .sql file, exports each result to data/out/*.csv
├── excel/
│   ├── Olist_Delivery_Sales_Analysis.xlsx   # live-formula model + what-if (371 formulas)
│   └── build_workbook.py
├── powerbi/                   # CSVs to import into Power BI
├── dashboard/                 # static blueprint (HTML + PNG) of the target dashboard
└── docs/
    ├── Case_Study.md          # full write-up
    ├── PowerBI_Build_Guide.md # data model, DAX measures, page layouts
    └── Resume_and_Interview_Prep.md
```
Excel workbook tabs
Tab	Contents
`README`	How the workbook works and definitions
`Summary`	Headline KPIs and monthly trend (live formulas) with charts
`What_If`	Impact model: change the yellow assumption cells; sensitivity table
`Data_Orders`	One row per delivered order (96,203 rows) that feeds every formula
`Late_vs_Review`	Review score and negative-review rate by delivery performance
`State_Priority`	Excess late orders by state with a "Fix?" toggle that feeds the What_If tab
`Seller_Scorecard`, `Seller_Priority`, `Category_Performance`	Static SQL outputs
Power BI model
Three tables (`fact_orders`, `fact_order_items`, `dim_sellers`) plus a `dim_date` table. All measures (Late Rate, Excess Late Orders, Negative Review %, Seller Excess Late, etc.) are documented in docs/PowerBI_Build_Guide.md.
6. Data
Source: Brazilian E-Commerce Public Dataset by Olist (Kaggle), released under CC BY-NC-SA 4.0. The raw files are not committed to this repository; download them yourself.
Table	Rows	Grain
`orders`	99,441	one row per order (status and timestamps)
`order_items`	112,650	one row per item in an order (price, freight, seller)
`order_payments`	103,886	one row per payment
`order_reviews`	99,224	review score and comments
`customers`	99,441	customer and state
`sellers`	3,095	seller and state
`products`	32,951	product category
`category_translation`	71	Portuguese → English category names
Analysis window: Jan 2017 – Aug 2018, delivered orders only (96,203 orders).
7. Metric definitions
Metric	Definition
GMV	Sum of item prices, excluding freight
AOV	GMV ÷ delivered orders
Late order	Delivered after the estimated delivery date shown at checkout
Late rate	Late orders ÷ delivered orders
Days vs promise	Actual delivery date minus estimated date (positive = late)
Negative review	Review score of 2 or lower
Excess late orders	Late orders − (orders × national late rate). Ranks where the most extra problem orders occur, so small states with a high rate don't dominate
8. How to reproduce
Requirements: Python 3.9+, `pandas`, `openpyxl`
```bash
git clone https://github.com/<your-username>/olist-delivery-sales-analysis.git
cd olist-delivery-sales-analysis
pip install -r requirements.txt

# 1. Download the Olist dataset from Kaggle and put the CSVs in ./data/
# 2. Build the database, run all SQL, build the workbook and dashboard blueprint
./run_all.sh
```
Then:
Open `excel/Olist_Delivery_Sales_Analysis.xlsx`; the What_If tab is the place to experiment.
To build the Power BI report, follow docs/PowerBI_Build_Guide.md and import the CSVs in `powerbi/`.
Sanity checks: 96,203 orders · GMV ≈ R$13.18M · AOV ≈ R$137 · late rate 8.13% · average review 4.16.
Porting the SQL (written for SQLite):
SQLite	MySQL	PostgreSQL
`julianday(a) - julianday(b)`	`DATEDIFF(a, b)`	`EXTRACT(EPOCH FROM (a - b)) / 86400`
`substr(x, 1, 7)`	`LEFT(x, 7)`	`LEFT(x, 7)`
`AVG(condition)`	works	`AVG((condition)::int)`
9. Skills demonstrated
SQL: multi-table joins, CTEs, window functions, conditional aggregation, views, cohort analysis, de-duplication, business-defined metrics
Excel: `SUMIFS` / `COUNTIFS` / `AVERAGEIFS` / `SUMPRODUCT` over 96K rows, what-if modelling with a sensitivity table, conditional formatting, charts
Power BI: star-style data model, DAX measures, a Date table, finding-led dashboard design
Business analysis: problem framing, prioritisation, honest sizing of impact, recommendations tied to evidence
10. Limitations
Correlation, not proof of causation. Late orders may differ in category, weight and region from on-time orders; a regression or matched comparison is needed to claim a precise effect.
No cost or margin data, so profit impact is not sized; GMV excludes freight.
Reviews are self-selected (about 1% of orders have none, and unhappy customers are more likely to write one).
A 2016–2018 sample. Patterns matter more than absolute volumes.
Seller late rates are item-weighted, so multi-item orders count once per item.
11. Next steps
Add carrier and package-weight data and build an order-level late-risk model (logistic regression) to flag at-risk shipments before dispatch.
Control for category, weight and distance to isolate the effect of lateness on reviews.
A/B test region-specific delivery promises.
Adapt the framework to quick commerce, where "late" is measured in minutes and analysed by dark store and delivery slot.
12. About me
[Your Name]: aspiring Business / Data Analyst focused on e-commerce and quick commerce, based in Bengaluru.
LinkedIn: [your LinkedIn URL]
Email: [your email]
---
Dataset © Olist, used under CC BY-NC-SA 4.0. This is an independent portfolio project and is not affiliated with Olist.
