import os
import pandas as pd
from sqlalchemy import create_engine

# Database connection 
DB_USER = "root"
DB_PASS = "PASSWORD"  
DB_HOST = "localhost"
DB_PORT = "3306"
DB_NAME = "olist_db"

engine = create_engine(f"mysql+pymysql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}")

# Mapping csv files to sql table names
csv_files = {
    'olist_customers_dataset.csv': 'customers',
    'olist_orders_dataset.csv': 'orders',
    'olist_order_items_dataset.csv': 'order_items',
    'olist_order_payments_dataset.csv': 'order_payments',
    'olist_order_reviews_dataset.csv': 'order_reviews',
    'olist_products_dataset.csv': 'products',
    'olist_sellers_dataset.csv': 'sellers',
    'olist_geolocation_dataset.csv': 'geolocation',
    'product_category_name_translation.csv': 'category_translation'
}

# Ingesting raw data into MySQL
data_dir = "../Raw_Data"

for file_name, table_name in csv_files.items():
    file_path = os.path.join(data_dir, file_name)
    df = pd.read_csv(file_path)
    df.to_sql(table_name, engine, if_exists='replace', index=False, chunksize=10000)
    print(f"Loaded {table_name} successfully.")