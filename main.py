from fastapi import FastAPI, HTTPException
import requests
import os
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

EBIRD_API_URL = "https://api.ebird.org/v2/data/obs/geo/recent"
EBIRD_TAXONOMY_URL = "https://api.ebird.org/v2/ref/taxonomy/ebird"
EBIRD_API_KEY = os.getenv("EBIRD_API_KEY")
DATABASE_URL = os.getenv("DATABASE_URL")

if not EBIRD_API_KEY:
    raise ValueError("EBIRD_API_KEY is missing! Set it in Azure.")

if not DATABASE_URL:
    raise ValueError("DATABASE_URL is missing! Set it in Azure.")

LAT = 56.2639
LON = 9.5018

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

@app.get("/birds")
async def get_bird_list():
    """Fetch recent bird observations with Danish names from the taxonomy."""
    headers = {"X-eBirdApiToken": EBIRD_API_KEY}
    params = {
        "lat": LAT,
        "lng": LON,
        "fmt": "json",
        "maxResults": 10,
        "includeProvisional": True
    }

    try:
        # Get the Danish taxonomy first
        danish_names = await get_danish_taxonomy()
        
        # Then get the observations
        response = requests.get(EBIRD_API_URL, headers=headers, params=params)
        response.raise_for_status()
        bird_data = response.json()

        birds = []
        for bird in bird_data:
            species_code = bird.get("speciesCode")
            bird_info = {
                "danishName": danish_names.get(species_code, bird.get("comName")),
                "scientificName": bird.get("sciName"),
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

    except requests.exceptions.HTTPError as e:
        raise HTTPException(status_code=e.response.status_code, detail=f"HTTP error occurred: {str(e)}")
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=500, detail=f"Error fetching bird data: {str(e)}")

@app.get("/health")
async def health_check():
    """Health check endpoint to verify that the API is running."""
    return {"status": "ok"}