import os
import random
from datetime import datetime, time, timedelta
import tempfile
from tqdm import tqdm
from database_operations import get_birds_from_database

AARHUS_CENTER = (56.1517, 10.2107)

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
                import DatabaseScripts.util.download_xeno as download_xeno
                sound_files = download_xeno.get_multiple_bird_sounds(scientific_name, temp_dir)
                
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