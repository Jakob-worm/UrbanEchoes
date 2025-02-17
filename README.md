# UrbanEchoes
To run the app in debug:
    CD urban_echoes_flutter
    flutter run

# Test
To start FastAPI app locally: uvicorn main:app --reload
To test the /birds Endpoint: curl http://127.0.0.1:8000/birds

# Deploy and test Azure
## one time
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm AzureCLI.msi
az --version

## Every time
az login
az webapp up --runtime PYTHON:3.9 --name UrbanEchoes-fastapi-backend --resource-group urbanEchoes-fastapi-backend-north-eu


Test: curl https://your-fastapi-app.azurewebsites.net/birds
Or open https://your-fastapi-app.azurewebsites.net/docs in a browser.


# For Home Pc
Remember to make the .env file
EBIRD_API_KEY=your_actual_ebird_api_key
DATABASE_URL=your_database_url