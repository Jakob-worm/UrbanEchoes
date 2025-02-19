import os
import requests
import psycopg2
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Database credentials
DB_HOST = os.getenv("DB_HOST")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
EBIRD_API_KEY = os.getenv("EBIRD_API_KEY")

# Connect to PostgreSQL
conn = psycopg2.connect(
    host=DB_HOST,
    dbname=DB_NAME,
    user=DB_USER,
    password=DB_PASSWORD,
    sslmode="require"
)
cursor = conn.cursor()

# Fetch birds data from eBird API
ebird_url = "https://api.ebird.org/v2/ref/taxonomy/ebird?fmt=json"
headers = {"X-eBirdApiToken": EBIRD_API_KEY}
response = requests.get(ebird_url, headers=headers)
birds = response.json()

# Insert birds into PostgreSQL
for bird in birds:
    cursor.execute(
        "INSERT INTO birds (common_name, scientific_name) VALUES (%s, %s) ON CONFLICT DO NOTHING",
        (bird["comName"], bird["sciName"]),
    )

conn.commit()
cursor.close()
conn.close()
print("Birds table populated successfully!")
