# weather_api.py
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import List
import random
from datetime import datetime, timedelta
import uvicorn
import os

app = FastAPI(
    title="Weather Microservice", 
    description="Weather data microservice for IoT platform",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve static files (frontend)
app.mount("/static", StaticFiles(directory="static"), name="static")

# Data models
class City(BaseModel):
    id: str
    name: str

class WeatherData(BaseModel):
    city: str
    condition: str
    temperature: int
    humidity: int
    wind_speed: float
    timestamp: str

class ForecastDay(BaseModel):
    date: str
    condition: str
    temperature: int

class ForecastResponse(BaseModel):
    city: str
    forecast: List[ForecastDay]

class CitiesResponse(BaseModel):
    cities: List[City]

# Mock data
CITIES = [
    {"id": "toronto", "name": "Toronto"},
    {"id": "vancouver", "name": "Vancouver"},
    {"id": "montreal", "name": "Montreal"},
    {"id": "calgary", "name": "Calgary"},
    {"id": "ottawa", "name": "Ottawa"},
    {"id": "winnipeg", "name": "Winnipeg"},
]

WEATHER_CONDITIONS = [
    "Sunny", "Partly Cloudy", "Cloudy", "Rainy", "Snowy", "Foggy"
]

def generate_mock_weather(city_name: str) -> WeatherData:
    """Generate mock weather data for a city"""
    return WeatherData(
        city=city_name,
        condition=random.choice(WEATHER_CONDITIONS),
        temperature=random.randint(-10, 35),
        humidity=random.randint(30, 90),
        wind_speed=round(random.uniform(5.0, 25.0), 1),
        timestamp=datetime.now().isoformat()
    )

def generate_mock_forecast(city_name: str) -> ForecastResponse:
    """Generate mock 5-day forecast for a city"""
    forecast_days = []
    for i in range(5):
        date = datetime.now() + timedelta(days=i+1)
        forecast_days.append(ForecastDay(
            date=date.strftime("%Y-%m-%d"),
            condition=random.choice(WEATHER_CONDITIONS),
            temperature=random.randint(-5, 30)
        ))
    
    return ForecastResponse(
        city=city_name,
        forecast=forecast_days
    )

# Frontend route
@app.get("/")
async def serve_frontend():
    """Serve the weather dashboard frontend"""
    return FileResponse("static/index.html")

# Health check
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

# API Routes
@app.get("/api/cities", response_model=CitiesResponse)
async def get_cities():
    """Get list of available cities"""
    return CitiesResponse(cities=[City(**city) for city in CITIES])

@app.get("/api/weather/{city_id}", response_model=WeatherData)
async def get_current_weather(city_id: str):
    """Get current weather for a specific city"""
    city = next((c for c in CITIES if c["id"] == city_id), None)
    if not city:
        raise HTTPException(status_code=404, detail="City not found")
    
    return generate_mock_weather(city["name"])

@app.get("/api/forecast/{city_id}", response_model=ForecastResponse)
async def get_weather_forecast(city_id: str):
    """Get 5-day weather forecast for a specific city"""
    city = next((c for c in CITIES if c["id"] == city_id), None)
    if not city:
        raise HTTPException(status_code=404, detail="City not found")
    
    return generate_mock_forecast(city["name"])

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)