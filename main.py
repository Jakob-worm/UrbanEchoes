from fastapi import FastAPI
import psycopg2

app = FastAPI()
DATABASE_URL = "postgresql://JakobWorm:SamsonDJ!@urbanechoes-fastapi-db.postgres.database.azure.com:5432/postgres"
conn = psycopg2.connect(DATABASE_URL)

@app.get("/")
def home():
    return {"message": "Azure FastAPI Backend is running!"}

@app.get("/test-db")
def test_db():
    cur = conn.cursor()
    cur.execute("SELECT version();")
    version = cur.fetchone()
    return {"db_version": version}
