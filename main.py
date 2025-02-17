from fastapi import FastAPI, HTTPException
import requests
import os
from dotenv import load_dotenv

load_dotenv()  # Load environment variables from .env file

app = FastAPI()

EBIRD_API_URL = "https://api.ebird.org/v2/ref/taxonomy/ebird"
EBIRD_API_KEY = os.getenv("EBIRD_API_KEY")  # Store in Azure Environment Variables
DATABASE_URL = os.getenv("DATABASE_URL")

if not EBIRD_API_KEY:
    raise ValueError("EBIRD_API_KEY is missing! Set it in Azure.")

if not DATABASE_URL:
    raise ValueError("DATABASE_URL is missing! Set it in Azure.")

@app.get("/health")
async def health_check():
    return {"status": "ok"}


@app.get("/birds")
async def get_bird_list():
    headers = {"X-eBirdApiToken": EBIRD_API_KEY}
    params = {"fmt": "json"}  # JSON format

    try:
        response = requests.get(EBIRD_API_URL, headers=headers, params=params)
        response.raise_for_status()
        bird_data = response.json()

        # Extract only common names
        bird_names = [bird["comName"] for bird in bird_data]

        return {"birds": bird_names}

    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=500, detail=f"Error fetching bird data: {str(e)}")
