import os
import random
from datetime import datetime, time
import json
import requests
from dotenv import load_dotenv
from tqdm import tqdm
from azure.storage.blob import BlobServiceClient
from azure.core.exceptions import ResourceNotFoundError
import tempfile

from database_connection import DatabaseConnection
import downloadXeno

# Danish birds with scientific names
DANISH_BIRDS = [
    ("Rødhals", "Erithacus rubecula"),
    ("Solsort", "Turdus merula"),
    ("Musvit", "Parus major"),
    ("Gråspurv", "Passer domesticus"),
    ("Blåmejse", "Cyanistes caeruleus"),
    ("Bogfinke", "Fringilla coelebs"),
    ("Grønirisk", "Chloris chloris"),
    ("Ringdue", "Columba palumbus")
]

# Aarhus center coordinates
AARHUS_CENTER = (56.1517, 10.2107)



class BirdSoundStorage:
    
    def __init__(self):
        self.connection_string = os.getenv("AZURE_STORAGE_CONNECTION_STRING")
        self.container_name = os.getenv("AZURE_STORAGE_CONTAINER_NAME", "bird-sounds")
        self.blob_service_client = BlobServiceClient.from_connection_string(self.connection_string)
        self.downloadXeno = downloadXeno()

    def create_container_if_not_exists(self):
        try:
            container_client = self.blob_service_client.get_container_client(self.container_name)
            container_client.get_container_properties()
        except ResourceNotFoundError:
            self.blob_service_client.create_container(self.container_name)
            print(f"Created container: {self.container_name}")

    def upload_sound_file(self, file_path, bird_name):
        try:
            blob_name = f"{bird_name.lower().replace(' ', '_')}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.mp3"
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=blob_name
            )

            with open(file_path, "rb") as data:
                blob_client.upload_blob(data)
            return blob_client.url

        except Exception as e:
            print(f"Error uploading file {file_path}: {e}")
            return None

def create_bird_observations_table(db):
    try:
        db.cursor.execute("DROP TABLE IF EXISTS bird_observations")
        db.cursor.execute("""
        CREATE TABLE bird_observations (
            id SERIAL PRIMARY KEY,
            bird_name VARCHAR(255) NOT NULL,
            scientific_name VARCHAR(255),
            sound_url TEXT,
            latitude DECIMAL(10, 7) NOT NULL,
            longitude DECIMAL(10, 7) NOT NULL,
            observation_date DATE NOT NULL,
            observation_time TIME NOT NULL,
            observer_id INTEGER,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            quantity: quantity,
        )
        """)
        db.commit()
        print("Table created successfully")
    except Exception as e:
        print(f"Error creating table: {e}")
        raise

def populate_sample_data(db, sound_storage):
    base_lat, base_lon = AARHUS_CENTER
    
    # Create temporary directory for sound files
    with tempfile.TemporaryDirectory() as temp_dir:
        try:
            print("Populating sample data...")
            for bird in tqdm(DANISH_BIRDS):  # First download one sound per species
                danish_name, scientific_name = bird
                
                # Get and download sound from Xeno-Canto
                download_url = downloadXeno.get_xenocanto_download_url(scientific_name)
                sound_url = None
                
                if download_url:
                    # Download to temp directory
                    temp_file_path = downloadXeno.download_sound_file(download_url, temp_dir)
                    if temp_file_path and sound_storage:
                        # Upload to Azure and get URL
                        sound_url = sound_storage.upload_sound_file(temp_file_path, danish_name)
                        os.remove(temp_file_path)  # Clean up temp file
                
                # Create multiple observations for this bird
                for _ in range(6):  # 6 observations per species
                    lat = base_lat + random.uniform(-0.05, 0.05)
                    lon = base_lon + random.uniform(-0.05, 0.05)
                    
                    observation_date = datetime.now().date()
                    observation_time = time(
                        hour=random.randint(5, 20),
                        minute=random.randint(0, 59)
                    )
                    
                    db.cursor.execute("""
                    INSERT INTO bird_observations 
                    (bird_name, scientific_name, sound_url, latitude, longitude, 
                     observation_date, observation_time, observer_id)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """, (
                        danish_name, scientific_name, sound_url, lat, lon,
                        observation_date, observation_time,
                        random.randint(1, 10), random.randint(1, 10)
                    ))
            
            db.commit()
            print("Sample data populated successfully")
            
        except Exception as e:
            print(f"Error populating data: {e}")
            raise

def main():
    db = DatabaseConnection()
    db.create_connection()
    
    sound_storage = None
    if os.getenv("AZURE_STORAGE_CONNECTION_STRING"):
        sound_storage = BirdSoundStorage()
        sound_storage.create_container_if_not_exists()
    else:
        print("Warning: Azure Storage connection string not found. Sounds will not be uploaded.")
    
    try:
        create_bird_observations_table(db)
        populate_sample_data(db, sound_storage)
        
        db.cursor.execute("SELECT COUNT(*) FROM bird_observations")
        count = db.cursor.fetchone()[0]
        print(f"Total records inserted: {count}")
        
    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        db.close_connection()

if __name__ == "__main__":
    main()