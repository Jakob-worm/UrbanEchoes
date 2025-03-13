
from DatabaseScripts.connection_and_oprations.database_connection import DatabaseConnection
from DatabaseScripts.util import BirdObservation


def insert_multiple_bird_observations(db, observations):
    """
    Inserts multiple bird observations into the bird_observations table.
    
    :param db: Database connection
    :param observations: List of BirdObservation instances
    """
    try:
        tuples = [obs.to_tuple() for obs in observations]  # Convert objects to tuples

        db.cursor.executemany("""
            INSERT INTO bird_observations (
                bird_name, scientific_name, sound_directory, latitude, longitude, 
                observation_date, observation_time, observer_id, quantity, is_test_data, test_batch_id
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, tuples)

        db.commit()
        print(f"Inserted {len(observations)} bird observations successfully!")
    except Exception as e:
        print(f"Error inserting bird observations: {e}")
        db.conn.rollback()  # Rollback in case of an error

if __name__ == "__main__":
    db = DatabaseConnection().create_connection()

    bird_observations_prototype = [
        BirdObservation("Solsort", "Turdus merula", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/turdus_merula", 56.171523, 10.189463, "2025-12-12", "12:30:00", 0, 2),
        BirdObservation("Blåmejse", "Cyanistes caeruleus", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/cyanistes_caeruleus", 56.171196, 10.190269, "2025-12-12", "12:35:00", 0, 1),
        BirdObservation("Blåmejse", "Cyanistes caeruleus", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/cyanistes_caeruleus", 56.172975, 10.193424, "2025-12-12", "12:37:00", 0, 1),
        BirdObservation("Ringdue", "Columba palumbus", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/columba_palumbus", 56.173651, 10.193487, "2025-12-12", "12:38:00", 0, 3),
        BirdObservation("Råge", "Corvus frugilegus", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/corvus_frugilegus", 56.173651, 10.193487, "2025-12-12", "12:38:00", 0, 2),
        BirdObservation("Solsort", "Turdus merula", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/turdus_merula", 56.174019, 10.191638, "2025-12-12", "12:40:00", 0, 3),
        BirdObservation("Grønirisk", "Chloris chloris", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/chloris_chloris", 56.173262, 10.191670, "2025-12-12", "12:41:00", 0, 1),
        BirdObservation("Sølv Måge", "Larus argentatus", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/larus_argentatus", 56.173317, 10.191036, "2025-12-12", "12:42:00", 0, 1),
        BirdObservation("Skovspurv", "Passer montanus", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/passer_montanus", 56.173395, 10.194014, "2025-12-12", "12:43:00", 0, 1),
    ]

    # Generating test data (with is_test_data=True) around (56.170661, 10.185762)
    bird_observations_test_home = [
        BirdObservation("Solsort", "Turdus merula", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/turdus_merula", 56.170661, 10.185762, "2025-12-12", "12:30:00", 0, 2, True),
        BirdObservation("Blåmejse", "Cyanistes caeruleus", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/cyanistes_caeruleus", 56.170820, 10.186100, "2025-12-12", "12:35:00", 0, 1, True),
        BirdObservation("Blåmejse", "Cyanistes caeruleus", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/cyanistes_caeruleus", 56.170500, 10.186300, "2025-12-12", "12:37:00", 0, 1, True),
        BirdObservation("Ringdue", "Columba palumbus", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/columba_palumbus", 56.170900, 10.186500, "2025-12-12", "12:38:00", 0, 3, True),
        BirdObservation("Råge", "Corvus frugilegus", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/corvus_frugilegus", 56.170750, 10.185950, "2025-12-12", "12:38:00", 0, 2, True),
        BirdObservation("Solsort", "Turdus merula", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/turdus_merula", 56.170550, 10.185800, "2025-12-12", "12:40:00", 0, 3, True),
        BirdObservation("Grønirisk", "Chloris chloris", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/chloris_chloris", 56.170950, 10.186200, "2025-12-12", "12:41:00", 0, 1, True),
        BirdObservation("Sølv Måge", "Larus argentatus", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/larus_argentatus", 56.170700, 10.185600, "2025-12-12", "12:42:00", 0, 1, True),
        BirdObservation("Skovspurv", "Passer montanus", "https://urbanechostorage.blob.core.windows.net/bird-sounds-test/passer_montanus", 56.170880, 10.185900, "2025-12-12", "12:43:00", 0, 1, True),
    ]

    # Insert into database
    insert_multiple_bird_observations(db, bird_observations_test_home)

    db.close_connection()