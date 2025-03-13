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
        self.container_name = os.getenv("AZURE_STORAGE_CONTAINER_NAME", "bird-sounds")
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

def populate_sample_data(db, sound_storage, test_batch_count=100):
    base_lat, base_lon = AARHUS_CENTER
    test_batch_id = f"TEST_BATCH_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    
    # Get birds from database
    birds_from_db = get_birds_from_database(db)
    
    if not birds_from_db:
        print("No birds found in the database. Exiting.")
        return
    
    # Create temporary directory for sound files
    with tempfile.TemporaryDirectory() as temp_dir:
        try:
            print("Downloading and storing bird sounds...")
            # Dictionary to store sound URLs for each species
            bird_sound_urls = {}
            
            for bird in tqdm(birds_from_db):
                bird_id, common_name, scientific_name, danish_name, region, is_common = bird
                
                if not scientific_name:
                    print(f"Warning: Bird with ID {bird_id} has no scientific name. Skipping.")
                    continue
                
                # Get multiple sound recordings for this species
                import downloadXeno
                sound_files = downloadXeno.get_multiple_bird_sounds(scientific_name, temp_dir)
                
                bird_sound_urls[scientific_name] = []
                for sound_file, recording_id in sound_files:
                    if sound_storage:
                        sound_url = sound_storage.upload_sound_file(sound_file, scientific_name, recording_id)
                        if sound_url:
                            bird_sound_urls[scientific_name].append(sound_url)
                        os.remove(sound_file)  # Clean up temp file
            
            print(f"Populating {test_batch_count} test observations...")
            # Create random observations
            for i in tqdm(range(test_batch_count)):
                # Randomly select a bird
                bird = random.choice(birds_from_db)
                bird_id, common_name, scientific_name, danish_name, region, is_common = bird
                
                # Skip if no scientific name
                if not scientific_name:
                    continue
                
                # Use danish_name if available, otherwise fall back to common_name
                bird_name = danish_name if danish_name else common_name
                
                # Randomly select a sound URL if available, otherwise None
                sound_url = None
                if scientific_name in bird_sound_urls and bird_sound_urls[scientific_name]:
                    sound_url = random.choice(bird_sound_urls[scientific_name])
                
                # Generate random location near Aarhus
                lat = base_lat + random.uniform(-0.1, 0.1)
                lon = base_lon + random.uniform(-0.1, 0.1)
                
                # Generate random date within the last 30 days
                random_days = random.randint(0, 30)
                observation_date = (datetime.now() - timedelta(days=random_days)).date()
                
                observation_time = time(
                    hour=random.randint(5, 20),
                    minute=random.randint(0, 59)
                )
                
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
            
            # Update the birds table with last_observed timestamp
            db.cursor.execute("""
            UPDATE birds 
            SET last_observed = CURRENT_TIMESTAMP 
            WHERE scientific_name IN (
                SELECT DISTINCT scientific_name 
                FROM bird_observations 
                WHERE test_batch_id = %s
            )
            """, (test_batch_id,))
            db.commit()
            print("Updated last_observed timestamps in birds table")
            
        except Exception as e:
            print(f"Error populating data: {e}")
            db.rollback()
            raise

def create_download_xeno_file():
    """Create downloadXeno.py as a separate file"""
    content = '''
import os
import json
import requests
import time
from pathlib import Path
from tqdm import tqdm

def get_xenocanto_download_url(scientific_name):
    """Get download URL for a bird sound from Xeno-Canto"""
    try:
        # Query the Xeno-Canto API
        query = f"https://xeno-canto.org/api/2/recordings?query={scientific_name.replace(' ', '+')}+q:A"
        response = requests.get(query)
        data = response.json()
        
        # Check if we got any recordings
        if data.get('numRecordings', '0') != '0' and data.get('recordings'):
            # Get the first recording info
            recording = data['recordings'][0]
            recording_id = recording.get('id')
            if recording_id:
                download_url = f"https://xeno-canto.org/{recording_id}/download"
                return download_url
    except Exception as e:
        print(f"Error getting Xeno-Canto URL for {scientific_name}: {e}")
    
    return None

def get_xenocanto_download_url_from_recording(recording):
    """Get download URL from a recording object"""
    try:
        recording_id = recording.get('id')
        if recording_id:
            download_url = f"https://xeno-canto.org/{recording_id}/download"
            return download_url
    except Exception as e:
        print(f"Error getting download URL from recording: {e}")
    
    return None

def get_multiple_xenocanto_recordings(scientific_name, count=20):
    """Get multiple high-quality recordings from Xeno-Canto"""
    recordings = []
    try:
        # Query the Xeno-Canto API for high-quality recordings (q:A) 
        query = f"https://xeno-canto.org/api/2/recordings?query={scientific_name.replace(' ', '+')}+q:A"
        response = requests.get(query)
        data = response.json()
        
        # Check if we got any recordings
        if data.get('numRecordings', '0') != '0' and data.get('recordings'):
            # Get the recordings, sort by quality
            all_recordings = data['recordings']
            # Sort by quality rating (A is best)
            all_recordings.sort(key=lambda x: x.get('q', 'E'), reverse=False)
            
            # Take requested number of recordings
            return all_recordings[:count]
    except Exception as e:
        print(f"Error getting Xeno-Canto recordings for {scientific_name}: {e}")
    
    return recordings

def download_sound_file(url, download_dir, recording_id=None):
    """Download sound file from URL and return local path"""
    try:
        if not url:
            return None
            
        # Create directory if it doesn't exist
        os.makedirs(download_dir, exist_ok=True)
        
        # Set default filename
        if recording_id:
            filename = f"{recording_id}.mp3"
        else:
            filename = f"sound_{int(time.time())}.mp3"
            
        local_path = os.path.join(download_dir, filename)
        
        # Download the file
        response = requests.get(url, stream=True)
        response.raise_for_status()
        
        with open(local_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
                
        return local_path
    except Exception as e:
        print(f"Error downloading sound file from {url}: {e}")
        return None

def get_multiple_bird_sounds(scientific_name, temp_dir, count=20):
    """Download multiple sound files for a given bird species"""
    sound_urls = []
    try:
        print(f"Downloading {count} sound recordings for {scientific_name}...")
        # Get best quality recordings sorted by quality
        recordings = get_multiple_xenocanto_recordings(scientific_name, count)
        
        for recording in tqdm(recordings, desc=f"{scientific_name} recordings"):
            if recording and recording.get('file-name') and recording.get('id'):
                download_url = get_xenocanto_download_url_from_recording(recording)
                if download_url:
                    file_path = download_sound_file(download_url, temp_dir, recording['id'])
                    if file_path:
                        sound_urls.append((file_path, recording['id']))
        
        return sound_urls
    except Exception as e:
        print(f"Error downloading sounds for {scientific_name}: {e}")
        return sound_urls
'''
    
    with open("downloadXeno.py", "w") as f:
        f.write(content)
    print("Created downloadXeno.py")

def main():
    load_dotenv()
    db = DatabaseConnection()
    db.create_connection()
    
    # First create downloadXeno.py as a separate file
    create_download_xeno_file()
    
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