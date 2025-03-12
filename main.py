from fastapi import FastAPI, HTTPException, Query, Depends
import requests
import psycopg2
import random
import os
import logging

from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from psycopg2.extras import RealDictCursor

load_dotenv()

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Change to specific domains for security
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Database connection function
def get_db_connection():
    return psycopg2.connect(
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT", 5432),
        database="urban_echoes_db ",
        sslmode="require"
    )

EBIRD_API_URL = "https://api.ebird.org/v2/data/obs/geo/recent"
EBIRD_TAXONOMY_URL = "https://api.ebird.org/v2/ref/taxonomy/ebird"
XENO_CANTO_API = "https://www.xeno-canto.org/api/2/recordings"
EBIRD_API_KEY = os.getenv("EBIRD_API_KEY")
DATABASE_URL = os.getenv("DATABASE_URL")

if not EBIRD_API_KEY:
    raise ValueError("EBIRD_API_KEY is missing! Set it in Azure.")

if not DATABASE_URL:
    raise ValueError("DATABASE_URL is missing! Set it in Azure.")

LAT = 56.2639 # Copenhagen coordinates TODO change to your location
LON = 9.5018 # Copenhagen coordinates  TODO change to your location

async def get_danish_taxonomy():
    """Fetch the eBird taxonomy with Danish names."""
    headers = {"X-eBirdApiToken": EBIRD_API_KEY}
    params = {
        "fmt": "json",
        "locale": "da"  # Request Danish names
    }
    
    try:
        response = requests.get(EBIRD_TAXONOMY_URL, headers=headers, params=params)
        response.raise_for_status()
        taxonomy_data = response.json()
        
        # Create a mapping of species codes to Danish names
        return {species["speciesCode"]: species["comName"] for species in taxonomy_data}
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=500, detail=f"Error fetching taxonomy: {str(e)}")
    

@app.get("/observations")
def get_observations():
    """Fetch all bird observations from the database."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute("""
            SELECT id, bird_name, scientific_name, sound_directory, latitude, longitude, observation_date, observation_time, observer_id, created_at, quantity, is_test_data, test_batch_id
            FROM bird_observations
        """)
        
        observations = cursor.fetchall()
        cursor.close()
        conn.close()
        
        return {"observations": observations}
    except Exception as e:
        logger.error(f"Error fetching observations: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal Server Error")


@app.get("/birds")
def get_birds():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        cursor.execute("SELECT common_name, scientific_name, danish_name FROM birds")
        birds = cursor.fetchall()
        cursor.close()
        conn.close()
        return {"birds": birds}
    except Exception as e:
        logger.error(f"Error fetching birds: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@app.get("/birdsound")
def get_bird_sound(scientific_name: str):
    params = {"query": scientific_name}
    response = requests.get(XENO_CANTO_API, params=params)

    if response.status_code != 200:
        return {"error": "Failed to fetch recordings"}

    data = response.json()
    recordings = data.get("recordings", [])

    if not recordings:
        return {"error": "No recordings found"}

    # Filter by quality (q:A is the best)
    high_quality = [rec for rec in recordings if rec.get("q") in ["A", "B"]]

    if not high_quality:
        return {"error": "No high-quality recordings available"}

    # Pick a random high-quality recording
    selected = random.choice(high_quality)
    sound_url = f"https://www.xeno-canto.org/{selected['id']}/download"

    return sound_url

@app.get("/search_birds")
def search_birds(query: str = Query(..., min_length=1, description="Bird search query")):
    """Search birds by Danish name dynamically"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT common_name, scientific_name 
            FROM birds 
            WHERE common_name ILIKE %s
            LIMIT 10
        """, (f"%{query}%",))

        birds = [{"common_name": row[0], "scientificName": row[1]} for row in cursor.fetchall()]
        
        cursor.close()
        conn.close()

        return {"birds": birds}
    except Exception as e:
        logger.error(f"Error searching birds: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@app.get("/birdsOLD")
async def get_bird_list():
    """Fetch recent bird observations with Danish names and corresponding sounds."""
    headers = {"X-eBirdApiToken": EBIRD_API_KEY}
    params = {
        "lat": LAT,
        "lng": LON,
        "fmt": "json",
        "maxResults": 100,
        "includeProvisional": True
    }

    try:
        danish_names = await get_danish_taxonomy()
        response = requests.get(EBIRD_API_URL, headers=headers, params=params)
        response.raise_for_status()
        bird_data = response.json()

        birds = []
        for bird in bird_data:
            species_code = bird.get("speciesCode")
            scientific_name = bird.get("sciName")

            bird_info = {
                "danishName": danish_names.get(species_code, bird.get("comName")),
                "scientificName": scientific_name,
                "observationDate": bird.get("obsDt"),
                "location": bird.get("locName"),
                "speciesCode": species_code
            }
            birds.append(bird_info)

        return {
            "birds": birds,
            "count": len(birds),
            "location": f"Coordinates: {LAT}, {LON}"
        }

    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=500, detail=f"Error fetching bird data: {str(e)}")


@app.get("/health")
async def health_check():
    """Health check endpoint to verify that the API is running."""
    return {"status": "ok"}