"""Load Olist CSVs into a SQLite database (olist.db). Run: python3 sql/00_load_data.py"""
import sqlite3, pandas as pd, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "data"); DB = os.path.join(ROOT, "olist.db")
if os.path.exists(DB): os.remove(DB)
con = sqlite3.connect(DB)
tables = {
 "customers": "olist_customers_dataset.csv",
 "orders": "olist_orders_dataset.csv",
 "order_items": "olist_order_items_dataset.csv",
 "order_payments": "olist_order_payments_dataset.csv",
 "order_reviews": "olist_order_reviews_dataset.csv",
 "products": "olist_products_dataset.csv",
 "sellers": "olist_sellers_dataset.csv",
 "category_translation": "product_category_name_translation.csv",
}
for t, f in tables.items():
    df = pd.read_csv(os.path.join(D, f))
    df.to_sql(t, con, index=False)
    print(f"{t:22s} {len(df):>8,} rows  cols={len(df.columns)}")
for ddl in [
 "CREATE INDEX ix_o_id ON orders(order_id)", "CREATE INDEX ix_o_cust ON orders(customer_id)",
 "CREATE INDEX ix_oi_o ON order_items(order_id)", "CREATE INDEX ix_oi_s ON order_items(seller_id)",
 "CREATE INDEX ix_oi_p ON order_items(product_id)", "CREATE INDEX ix_p_id ON products(product_id)",
 "CREATE INDEX ix_r_o ON order_reviews(order_id)", "CREATE INDEX ix_pay_o ON order_payments(order_id)",
 "CREATE INDEX ix_c_id ON customers(customer_id)", "CREATE INDEX ix_s_id ON sellers(seller_id)"]:
    con.execute(ddl)
con.commit(); con.close(); print("olist.db ready")
