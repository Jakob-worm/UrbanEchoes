from fastapi import FastAPI
import psycopg2

app = FastAPI()

@app.get("/")
def home():
    return {"message": "Azure FastAPI Backend is running!"}
