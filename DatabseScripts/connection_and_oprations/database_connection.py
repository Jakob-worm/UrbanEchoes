# Load environment variables from .env file
import os
from dotenv import load_dotenv
import psycopg2

load_dotenv()

class DatabaseConnection:
    def __init__(self):
        self.conn = None
        self.cursor = None
    
    def create_connection(self):
        # Database credentials
        DB_HOST = os.getenv("DB_HOST")
        DB_NAME = os.getenv("DB_NAME")
        DB_PORT = os.getenv("DB_PORT", 5432)  # Default to 5432 if not set
        DB_USER = os.getenv("DB_USER")
        DB_PASSWORD = os.getenv("DB_PASSWORD")
        
        # Connect to PostgreSQL
        try:
            self.conn = psycopg2.connect(
                user=DB_USER,
                password=DB_PASSWORD,
                host=DB_HOST,
                port=DB_PORT,
                database="urban_echoes_db ",
                sslmode="require",
                connect_timeout=15
            )
            self.cursor = self.conn.cursor()
            return self
        except psycopg2.OperationalError as e:
            print(f"Error connecting to the database: {e}")
            exit(1)

    def commit(self):
        if self.conn:
            self.conn.commit()

    def close_connection(self):
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
            print("Database connection closed.")