import requests
from dotenv import load_dotenv
from tqdm import tqdm

from populatedatabase import connect_to_database
from populatedatabase.test_obervastions_database import EBIRD_API_KEY

cursor = connect_to_database.create_connection()

# Create table if it doesn't exist
cursor.execute("""
CREATE TABLE IF NOT EXISTS birds (
    id SERIAL PRIMARY KEY,
    common_name VARCHAR(255),
    scientific_name VARCHAR(255),
    danish_name VARCHAR(255),
    region VARCHAR(255),
    last_observed TIMESTAMP,
    UNIQUE (scientific_name, region)
)
""")

### 1️⃣ Fetch ALL birds for a country (e.g., Denmark)
taxonomy_url = "https://api.ebird.org/v2/ref/taxonomy/ebird?fmt=json&locale=da"
headers = {"X-eBirdApiToken": EBIRD_API_KEY}
response = requests.get(taxonomy_url, headers=headers)
all_birds = response.json()

for bird in tqdm(all_birds, desc="Inserting birds into database"):
    common_name = bird["comName"]  # English name
    scientific_name = bird["sciName"]
    danish_name = bird.get("danishName", "")  # Danish name
    region = "Denmark"  # Change this for different countries

    # Insert into database
    cursor.execute(
        """
        INSERT INTO birds (common_name, scientific_name, danish_name, region)
        VALUES (%s, %s, %s, %s)
        ON CONFLICT (scientific_name, region) DO UPDATE
        SET common_name = EXCLUDED.common_name,
            danish_name = EXCLUDED.danish_name
        """,
        (common_name, scientific_name, danish_name, region),
    )

### 2️⃣ Fetch RECENT observations for a small local area
latitude, longitude = 56.2639, 9.5018
recent_url = f"https://api.ebird.org/v2/data/obs/geo/recent?lat={latitude}&lng={longitude}&maxResults=500"
recent_response = requests.get(recent_url, headers=headers)
recent_birds = recent_response.json()

for bird in tqdm(recent_birds, desc="Updating recent observations"):
    common_name = bird["comName"]
    scientific_name = bird["sciName"]
    
    # Mark as recently observed (e.g., store timestamp)
    cursor.execute(
        "UPDATE birds SET last_observed = NOW() WHERE scientific_name = %s AND region = 'Denmark'",
        (scientific_name,),
    )

conn.commit()
cursor.close()
conn.close()
print("Birds table updated successfully!")
