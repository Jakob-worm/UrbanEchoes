from database_connection import DatabaseConnection

def create_bird_observations_table(db, reset_table=False):
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