# UrbanEchoes
To run the app in debug:
    CD urban_echoes_flutter
    flutter run

# Venv Use it to create acurate requirements.txt
venv\Scripts\activate
pip freeze > requirements.txt

# Test
To start FastAPI app locally: uvicorn main:app --reload
To test the /birds Endpoint: curl http://127.0.0.1:8000/birds

# When debugging on chrome
flutter run -d chrome --web-browser-flag "--disable-web-security"

# .env update
AZURE_STORAGE_CONNECTION_STRING=your_connection_string
AZURE_STORAGE_CONTAINER_NAME=bird-sounds  # or your preferred container name

To get the Azure Storage connection string:

Go to Azure Portal
Navigate to your Storage Account
Under "Security + networking", click "Access keys"
Copy the connection string


# Deploy and test Azure
## one time
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm AzureCLI.msi
az --version

## Every time
Login: az login
Deploy: az webapp up --name UrbanEchoes-fastapi-backend --resource-group urbanEchoes-fastapi-backend-north-eu --location northeurope
Verify deployment: az webapp show --name UrbanEchoes-fastapi-backend --resource-group urbanEchoes-fastapi-backend-north-eu

https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net/birds



Test: curl https://UrbanEchoes-fastapi-backend.azurewebsites.net/birds
Or open https://UrbanEchoes-fastapi-backend.azurewebsites.net/birds in a browser.

