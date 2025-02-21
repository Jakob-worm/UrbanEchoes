import os
import requests
import psycopg2
from dotenv import load_dotenv
from tqdm import tqdm

from populatedatabase import database_connection

#create connection to database
db = database_connection.DatabaseConnection()
db.create_connection()

# Create table if it doesn't exist
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
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
""")


