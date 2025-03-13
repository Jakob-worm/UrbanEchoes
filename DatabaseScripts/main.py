import os
from dotenv import load_dotenv
from database_connection import DatabaseConnection
from bird_sound_storage import BirdSoundStorage
from database_operations import create_bird_observations_table
from populate_sample_data import populate_sample_data

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