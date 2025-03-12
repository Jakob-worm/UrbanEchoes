from connection_and_oprations.database_connection import DatabaseConnection

def insert_bird_observation(db, bird_name, scientific_name, sound_directory, latitude, longitude, 
                            observation_date, observation_time, observer_id=None, quantity=1, 
                            is_test_data=False, test_batch_id=None):
    """
    Inserts a bird observation into the bird_observations table.
    """
    try:
        db.cursor.execute("""
            INSERT INTO bird_observations (
                bird_name, scientific_name, sound_directory, latitude, longitude, 
                observation_date, observation_time, observer_id, quantity, is_test_data, test_batch_id
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (bird_name, scientific_name, sound_directory, latitude, longitude, 
              observation_date, observation_time, observer_id, quantity, is_test_data, test_batch_id))
        
        db.commit()
        print(f"Inserted observation for {bird_name} on {observation_date} at {observation_time}")
    except Exception as e:
        print(f"Error inserting bird observation: {e}")
        db.conn.rollback()  # Rollback on error

def insert_multiple_bird_observations(db, observations):
    """
    Inserts multiple bird observations into the bird_observations table.
    
    :param db: Database connection
    :param observations: List of tuples containing bird observation data
    """
    try:
        db.cursor.executemany("""
            INSERT INTO bird_observations (
                bird_name, scientific_name, sound_directory, latitude, longitude, 
                observation_date, observation_time, observer_id, quantity, is_test_data, test_batch_id
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, observations)

        db.commit()
        print(f"Inserted {len(observations)} bird observations successfully!")
    except Exception as e:
        print(f"Error inserting bird observations: {e}")
        db.conn.rollback()  # Rollback in case of an error

if __name__ == "__main__":
    db = DatabaseConnection().create_connection()

     # Example list of bird observations
    bird_observations = [
        ("Sol sort", "Turdus merula", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/turdus_merula/", 56.171523, 10.189463, "2025-12-12", "12:30:00", 0, 2, False, None),
        ("Blåmejse", "Cyanistes caeruleus", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/cyanistes_caeruleus/", 56.171196, 10.190269, "2025-12-12", "12:35:00", 0, 1, False, None),
        ("Blåmejse", "Cyanistes caeruleus", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/cyanistes_caeruleus/", 56.172975, 10.193424, "2025-12-12", "12:37:00", 0, 1, False, None),
        ("RingDue", "Columba palumbus", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/columba_palumbus/", 56.173651, 10.193487, "2025-12-12", "12:38:00", 0, 3, False, None),
        ("Råge", "Corvus frugilegus", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/corvus_frugilegus/", 56.173651, 10.193487, "2025-12-12", "12:38:00", 0, 2, False, None),
        ("Sol sort", "Turdus merula", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/turdus_merula/",56.174019, 10.191638, "2025-12-12", "12:40:00", 0, 3, False, None),
        ("Grønirisk", "Chloris chloris", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/chloris_chloris/", 56.173262, 10.191670, "2025-12-12", "12:41:00", 0, 1, False, None),
        ("Sølv Måge", "Larus argentatus", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/larus_argentatus/", 56.173317, 10.191036, "2025-12-12", "12:42:00", 0, 1, False, None),
        ("Skovspurv", "Passer montanus", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/passer_montanus/", 56.173395, 10.194014, "2025-12-12", "12:43:00", 0, 1, False, None),
    ]

    insert_multiple_bird_observations(db, bird_observations)

    db.close_connection()
