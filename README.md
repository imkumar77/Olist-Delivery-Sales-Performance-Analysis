## Olist-Delivery-Sales-Analysis

The objective of this project is to find out where an e-commerce marketplace loses customer satisfaction because of late deliveries, and what operations should fix first. The analysis covers 96,203 delivered orders from Jan 2017 to Aug 2018. By finding where lateness is concentrated and what it costs in reviews, the goal is to help operations plan fixes in order of impact.

📎 Code: https://github.com/imkumar77/Olist-Delivery-Sales-Performance-Analysis/edit/main/README.md

# Problem Statement

Olist is a Brazilian marketplace that connects small sellers to customers. Leadership sees an average review of 4.16 and an 8.13% late-delivery rate, but does not know how much lateness really hurts satisfaction, where it is concentrated, or what is worth fixing first. Without this clarity, operational effort may go to low-impact areas.

The problem is to analyse the order data, uncover the patterns behind late deliveries and bad reviews, and build a prioritised plan with an estimate of its impact.

# Approach
- Data Understanding
- Reviewed 8 related tables to understand the structure, joins, data quality and grain (order, item, review).
- Data Cleaning and Modelling
- Kept delivered orders only, fixed duplicate rows caused by multi-item orders and multiple reviews, and built reusable SQL views.
- Exploratory Data Analysis (EDA)
- Studied GMV, order value, delivery time, late rate and review scores over time, by state, category and seller.
- Driver Analysis
- Measured how delivery delay affects review scores and repeat purchase.
- Prioritisation and What-if Analysis
- Built an “excess late orders” metric and an Excel what-if model to estimate the impact of fixing the worst areas.
- Final Recommendations
- Summarised findings and gave data-backed actions for operations.

Raw Data
https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

Data Understanding
Table	Rows	What it holds
orders	99,441	order status and timestamps
order_items	112,650	items, price, freight, seller
order_payments	103,886	payment type and value
order_reviews	99,224	review score and comments
customers	99,441	customer and state
sellers	3,095	seller and state
products	32,951	product category

<img width="607" height="217" alt="image" src="https://github.com/user-attachments/assets/f273dddc-06a2-4d56-bcc8-7fede1fea3dc" />


Data Dictionary

<img width="738" height="182" alt="image" src="https://github.com/user-attachments/assets/8f81938d-be2c-427a-995d-f30eae5fe5d0" />

---

# Exploratory Data Analysis (EDA)

1. Delivered orders only
Cancelled and unavailable orders have no delivery outcome. Only delivered orders with a delivery date were kept (8 delivered orders had no date and were dropped).

2. Analysis window
2016 and Sep–Oct 2018 contain very few orders and would distort trends, so the window is Jan 2017 to Aug 2018 (96,203 orders).

3. Multi-item orders
One order can have several item rows, so revenue was aggregated to order level before any order metric was calculated.

sql
~~~
SELECT order_id, COUNT(*) AS items,
       SUM(price) AS item_revenue,
       SUM(freight_value) AS freight
FROM order_items
GROUP BY order_id;
~~~

4. Multiple reviews per order
Some orders have more than one review. The scores were averaged to keep one row per order.

sql
~~~
SELECT order_id, AVG(review_score) AS review_score
FROM order_reviews
GROUP BY order_id;
~~~

5. Defining a late order
A late order is one delivered after the date promised at checkout.

sql
~~~
CASE WHEN order_delivered_customer_date > order_estimated_delivery_date
     THEN 1 ELSE 0 END AS is_late
~~~
6. Delay buckets
Orders were grouped by days late versus the promise, to see where reviews break.

sql
~~~
CASE WHEN days_vs_promise <= -7 THEN '1. 7+ days early'
     WHEN days_vs_promise <= 0  THEN '2. 0-7 days early'
     WHEN days_vs_promise <= 3  THEN '3. 1-3 days late'
     WHEN days_vs_promise <= 7  THEN '4. 4-7 days late'
     WHEN days_vs_promise <= 14 THEN '5. 8-14 days late'
     ELSE '6. 15+ days late' END AS bucket
~~~


# Univariate Analysis

<img width="802" height="447" alt="image" src="https://github.com/user-attachments/assets/9901e117-3204-46c5-a83d-91fbf22be1f9" />


Observation:
Monthly GMV grew about 9x, from R$112K in Jan-17 to R$988K in Nov-17 (Black Friday), then stayed at a higher level. The late rate stayed near 3–5% for most of 2017, then spiked to 14.3% in Nov-17 and 21.4% in Mar-18.

Note: We have many more observations

https://github.com/imkumar77/Olist-Delivery-Sales-Performance-Analysis/blob/main/Olist_Delivery_Sales_Analysis.xlsx

# Bivariate Analysis

<img width="437" height="260" alt="image" src="https://github.com/user-attachments/assets/ab21e322-da43-4c39-bcc4-675d068762e0" />

Observation:
Orders up to 3 days late still score 3.77, but at 4–7 days late the average review falls to 2.32 and beyond 8 days it sits at about 1.7. Orders that arrive on time score 4.30.

Observation:
Rio de Janeiro has the most excess late orders (663), followed by Bahia (193) and Ceará (92).

<img width="1538" height="980" alt="image" src="https://github.com/user-attachments/assets/e908f19c-9892-4aa4-8d7a-d9c24c06cdce" />


# What-if Analysis (Optimisation)

<img width="1206" height="640" alt="image" src="https://github.com/user-attachments/assets/7678393c-431c-4165-893d-d5d0e815713e" />


Share of excess lateness eliminated (RJ, BA, CE)	Late orders avoided	New late rate	Negative reviews avoided
25%	237	7.88%	106
50%	474	7.64%	212
75%	711	7.39%	319
100%	948	7.15%	425

---

# Insights

1. Insights from Univariate Analysis

- Average delivery takes 12.5 days, while the average promise is 23.6 days. Most orders arrive early, so lateness is a tail problem.
- The overall late rate is 8.13%, and freight is 14.3% of order value.
- The top 10% of sellers generate 67% of GMV.
- Health & Beauty (10.1%), Watches & Gifts (9.6%) and Bed, Bath & Table (8.4%) are the biggest categories by GMV.
- Nov-17 (Black Friday month) was the peak: 7,288 orders and R$988K GMV.

2. Insights from Bivariate Analysis

- Late orders average a review of 2.57, against 4.30 for on-time orders.
- 54% of late orders get a 1–2 star review, against 9.2% for on-time orders, about 6 times higher.
- Rio de Janeiro, Bahia and Ceará hold 66% of all excess late orders; Rio alone holds 46%. São Paulo has a late rate of only 5.9%, against 13.5% in Rio.
- Cross-state orders are late 9.0% of the time and take 15.0 days, against 6.0% and 7.9 days for same-state orders.
- Black Friday month was 7.6% of orders but 13.3% of all late orders. The late rate stayed at 20–23% for six days in a row.
- Customers whose first order was late repeat 28% less often (2.16% vs 2.98%). Only about 3% of customers ever reorder, so the revenue effect is small.

3. Insights from What-if Analysis

- Removing half of the excess lateness in RJ, BA and CE avoids about 474 late orders and 212 negative reviews, and brings the national late rate from 8.13% to 7.64%.
- The repeat-purchase revenue gain is only about R$530, so the real value is reputation and ratings.

---

# Recommendations

- Fix last-mile delivery in RJ, BA and CE first
These three states hold 66% of excess late orders. Carrier reviews and regional fulfilment changes here give the biggest gain.

- Put the 5 worst high-volume sellers on an SLA plan
Five sellers add about 214 excess late orders, including one in MA with a 23.6% late rate. Targeted shipping-time improvements are controllable and quick.

- Build a peak-season playbook
Black Friday produced 13.3% of late orders from 7.6% of volume. Plan carrier capacity, order cut-offs and delivery estimates before big campaigns.

- A/B test region-aware delivery promises
Promises average 23.6 days against 12.5 actual. Testing longer promises in high-risk regions could cut late orders. This is a hypothesis to test.

- Track late rate and review score monthly
Use the Power BI dashboard to watch the late rate, excess late orders and negative review percentage.

---

# Conclusion

This project analysed 96,203 marketplace orders using SQL, Excel and Power BI. Late deliveries clearly hurt customer satisfaction, and the damage starts when an order is 4 or more days late. Lateness is concentrated in three states, a handful of sellers and peak-demand periods, so a focused plan can fix a large share of it.

The what-if model shows that halving excess lateness in the priority states avoids about 474 late orders and 212 negative reviews. Because repeat purchase is rare, the main benefit is better reviews and reputation, not repeat sales. The analysis is correlational, has no cost or margin data and uses a 2016–2018 sample, so the next step is to test the recommendations with an experiment.
