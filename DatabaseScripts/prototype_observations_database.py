import os
import random
from datetime import datetime, time, timedelta
import json
import requests
from dotenv import load_dotenv
from tqdm import tqdm
from azure.storage.blob import BlobServiceClient
from azure.core.exceptions import ResourceNotFoundError
import tempfile


from database_connection import DatabaseConnection

# Aarhus center coordinates
AARHUS_CENTER = (56.1517, 10.2107)

# Toggle to reset the table (delete existing table before creating a new one)
reset_table = False  # Set to True to reset the table


class BirdSoundStorage:
    def __init__(self):
        self.connection_string = os.getenv("AZURE_STORAGE_CONNECTION_STRING")
        self.container_name = os.getenv("AZURE_STORAGE_CONTAINER_NAME", "bird-sounds-test")
        self.blob_service_client = BlobServiceClient.from_connection_string(self.connection_string)
    
    def create_container_if_not_exists(self):
        try:    
            container_client = self.blob_service_client.get_container_client(self.container_name)
            container_client.get_container_properties()
        except ResourceNotFoundError:
            self.blob_service_client.create_container(self.container_name)
            print(f"Created container: {self.container_name}")

    def upload_sound_file(self, file_path, scientific_name, recording_id=None):
        try:
            # Format: bird-sounds/scientific_name/timestamp_id.mp3
            folder_path = scientific_name.lower().replace(' ', '_')
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            blob_name = f"{folder_path}/{timestamp}_{random.randint(1000, 9999)}.mp3"
            
            if recording_id:
                blob_name = f"{folder_path}/{recording_id}.mp3"
            
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
        if reset_table:
            db.cursor.execute("DROP TABLE IF EXISTS bird_observations")
        
        db.cursor.execute("""
        CREATE TABLE IF NOT EXISTS bird_observations (
            id SERIAL PRIMARY KEY,
            bird_name VARCHAR(255) NOT NULL,
            scientific_name VARCHAR(255),
            sound_directory TEXT,
            latitude DECIMAL(10, 7) NOT NULL,
            longitude DECIMAL(10, 7) NOT NULL,
            observation_date DATE NOT NULL,
            observation_time TIME NOT NULL,
            observer_id INTEGER,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            quantity INTEGER DEFAULT 1,
            is_test_data BOOLEAN DEFAULT FALSE,
            test_batch_id VARCHAR(50) NULL
        )
        """)
        db.commit()
        print("Table created successfully")
    except Exception as e:
        print(f"Error creating table: {e}")
        raise

def get_birds_from_database(db):
    """Get all birds from the birds table in the database"""
    birds = []
    try:
        db.cursor.execute("""
        SELECT id, common_name, scientific_name, danish_name, region, is_common
        FROM birds
        """)
        birds = db.cursor.fetchall()
        print(f"Found {len(birds)} birds in the database")
        return birds
    except Exception as e:
        print(f"Error fetching birds from database: {e}")
        return birds
    


def get_local_bird_sounds(base_folder):
        """Retrieve local bird sound files from a given base folder."""
        bird_sound_map = {}

        for root, _, files in os.walk(base_folder):
            scientific_name = os.path.basename(root)  # Assume folder name is scientific name
            bird_sound_map[scientific_name] = [os.path.join(root, f) for f in files if f.endswith('.mp3')]

        return bird_sound_map

def populate_sample_data(db, sound_storage, test_batch_count=100, sound_folder="path/to/sound_files"):
    base_lat, base_lon = AARHUS_CENTER
    test_batch_id = f"TEST_BATCH_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    
    # Get birds from the database
    birds_from_db = get_birds_from_database(db)
    
    if not birds_from_db:
        print("No birds found in the database. Exiting.")
        return
    
    # Get local sound files
    bird_sound_files = get_local_bird_sounds(sound_folder)
    
    print(f"Populating {test_batch_count} test observations...")
    
    for _ in tqdm(range(test_batch_count)):
        bird = random.choice(birds_from_db)
        bird_id, common_name, scientific_name, danish_name, region, is_common = bird

        if not scientific_name:
            continue

        bird_name = danish_name if danish_name else common_name

        # Check if there are local sound files
        sound_url = None
        if scientific_name in bird_sound_files and bird_sound_files[scientific_name]:
            sound_file = random.choice(bird_sound_files[scientific_name])
            sound_url = sound_storage.upload_sound_file(sound_file, scientific_name)
        
        lat = base_lat + random.uniform(-0.1, 0.1)
        lon = base_lon + random.uniform(-0.1, 0.1)
        random_days = random.randint(0, 30)
        observation_date = (datetime.now() - timedelta(days=random_days)).date()
        observation_time = time(hour=random.randint(5, 20), minute=random.randint(0, 59))

        db.cursor.execute("""
        INSERT INTO bird_observations 
        (bird_name, scientific_name, sound_url, latitude, longitude, 
         observation_date, observation_time, observer_id, quantity, 
         is_test_data, test_batch_id)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            bird_name, scientific_name, sound_url, lat, lon,
            observation_date, observation_time,
            random.randint(1, 10), random.randint(1, 10),
            True, test_batch_id
        ))

    db.commit()
    print(f"Sample data populated successfully. Test batch ID: {test_batch_id}")


def main():
    load_dotenv()
    db = DatabaseConnection()
    db.create_connection()
    
    sound_storage = None
    if os.getenv("AZURE_STORAGE_CONNECTION_STRING"):
        sound_storage = BirdSoundStorage()
        sound_storage.create_container_if_not_exists()
    else:
        print("Warning: Azure Storage connection string not found. Sounds will not be uploaded.")
    
    try:
        # Ensure birds table exists (we're not modifying it, just checking)
        db.cursor.execute("""
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_name = 'birds'
        )
        """)
        birds_table_exists = db.cursor.fetchone()[0]
        
        if not birds_table_exists:
            print("The 'birds' table does not exist. Creating it...")
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
            db.commit()
            print("Created 'birds' table, but it's empty. Please add birds before running this script.")
            return
        
        # Create or update the bird_observations table
        create_bird_observations_table(db)
        
        # Populate sample data using birds from the database
        populate_sample_data(db, sound_storage, test_batch_count=100)
        
        # Print statistics
        db.cursor.execute("SELECT COUNT(*) FROM bird_observations WHERE is_test_data = TRUE")
        test_count = db.cursor.fetchone()[0]
        print(f"Total test records inserted: {test_count}")
        
        db.cursor.execute("""
        SELECT b.scientific_name, b.danish_name, b.common_name, COUNT(o.id) 
        FROM birds b
        LEFT JOIN bird_observations o ON b.scientific_name = o.scientific_name
        WHERE o.is_test_data = TRUE
        GROUP BY b.scientific_name, b.danish_name, b.common_name
        ORDER BY COUNT(o.id) DESC
        """)
        bird_counts = db.cursor.fetchall()
        print("\nTest observations by bird species:")
        for scientific_name, danish_name, common_name, count in bird_counts:
            display_name = danish_name if danish_name else common_name
            print(f"{display_name} ({scientific_name}): {count} observations")
        
    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        db.close_connection()

if __name__ == "__main__":
    main()