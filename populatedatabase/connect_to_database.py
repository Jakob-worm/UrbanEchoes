# Load environment variables from .env file
import os
from dotenv import load_dotenv
import psycopg2


load_dotenv()

class connect_to_database:

    
    def create_connection():
        # Database credentials
        DB_HOST = os.getenv("DB_HOST")
        DB_NAME = os.getenv("DB_NAME")
        DB_PORT = os.getenv("DB_PORT", 5432)  # Default to 5432 if not set
        DB_USER = os.getenv("DB_USER")
        DB_PASSWORD = os.getenv("DB_PASSWORD")
        EBIRD_API_KEY = os.getenv("EBIRD_API_KEY")
        
        # Connect to PostgreSQL
        try:
            conn = psycopg2.connect(
                user=DB_USER,
                password=DB_PASSWORD,
                host=DB_HOST,
                port=DB_PORT,
                database="urban_echoes_db ",
                sslmode="require",
                connect_timeout=15
            )
            cursor = conn.cursor()
            return cursor
        except psycopg2.OperationalError as e:
            print(f"Error connecting to the database: {e}")
            exit(1)