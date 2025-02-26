import os
import requests
from dotenv import load_dotenv
from tqdm import tqdm

from database_connection import DatabaseConnection
# Toggle to reset the table (delete existing table before creating a new one)
reset_table = True  # Set to True to reset the table

# Create connection to database
db = DatabaseConnection()
db.create_connection()


# Drop existing table if reset_table is True
if reset_table:
    db.cursor.execute("DROP TABLE IF EXISTS birds CASCADE;")
    print("Existing 'birds' table dropped.")

# Create table if it doesn't exist
db.cursor.execute("""
CREATE TABLE IF NOT EXISTS birds (
    id SERIAL PRIMARY KEY,
    common_name VARCHAR(255),
    scientific_name VARCHAR(255),
    danish_name VARCHAR(255),
    region VARCHAR(255),
    last_observed TIMESTAMP,
    is_common BOOLEAN DEFAULT FALSE,
    UNIQUE (scientific_name, region)
)
""")

# Step 1: Get the region code for Denmark (DK)
region_birds_url = "https://api.ebird.org/v2/product/spplist/DK"
headers = {"X-eBirdApiToken": os.getenv("EBIRD_API_KEY")}
region_response = requests.get(region_birds_url, headers=headers)
denmark_bird_codes = region_response.json()

# Step 2: Get the full taxonomy info
taxonomy_url = "https://api.ebird.org/v2/ref/taxonomy/ebird?fmt=json&locale=da"
taxonomy_response = requests.get(taxonomy_url, headers=headers)
all_birds_taxonomy = taxonomy_response.json()

# Create a dictionary of birds that occur in Denmark
denmark_birds = {}
for bird in all_birds_taxonomy:
    if bird["speciesCode"] in denmark_bird_codes:
        common_name = bird["comName"]
        scientific_name = bird["sciName"]
        
        # Skip hybrids, unidentified species, and domestic/escaped variants
        if " x " in scientific_name.lower() or "hybrid" in common_name.lower():
            continue
        if " sp." in scientific_name or "sp." in common_name:
            continue
        if any(term in common_name.lower() for term in ["domestic", "escaped", "feral"]):
            continue
        
        # Now this is a valid bird for our database
        denmark_birds[bird["speciesCode"]] = bird

# Insert Denmark birds into database
for bird_code, bird in tqdm(denmark_birds.items(), desc="Inserting Denmark birds"):
    common_name = bird["comName"]  
    scientific_name = bird["sciName"]
    danish_name = bird.get("name", "")  
    region = "Denmark"

    # Insert into database
    db.cursor.execute(
        """
        INSERT INTO birds (common_name, scientific_name, danish_name, region, is_common)
        VALUES (%s, %s, %s, %s, TRUE)
        ON CONFLICT (scientific_name, region) DO UPDATE
        SET common_name = EXCLUDED.common_name,
            danish_name = EXCLUDED.danish_name,
            is_common = TRUE
        """,
        (common_name, scientific_name, danish_name, region),
    )

# Step 3: Get recent observations to mark birds as recently seen
latitude, longitude = 56.2639, 9.5018  
recent_url = f"https://api.ebird.org/v2/data/obs/geo/recent?lat={latitude}&lng={longitude}&maxResults=500"
recent_response = requests.get(recent_url, headers=headers)
recent_birds = recent_response.json()

for bird in tqdm(recent_birds, desc="Updating recent observations"):
    scientific_name = bird["sciName"]
    
    # Skip updating hybrids and problematic entries
    if " x " in scientific_name.lower() or " sp." in scientific_name:
        continue
        
    # Mark as recently observed
    db.cursor.execute(
        "UPDATE birds SET last_observed = NOW() WHERE scientific_name = %s AND region = 'Denmark'",
        (scientific_name,),
    )

# Commit changes and close connection
db.conn.commit()
db.cursor.close()
db.conn.close()
print("Birds table updated successfully with clean Denmark birds data!")
