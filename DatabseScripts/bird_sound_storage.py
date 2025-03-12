import os
from datetime import datetime
import random
from azure.storage.blob import BlobServiceClient
from azure.core.exceptions import ResourceNotFoundError

class BirdSoundStorage:
    def __init__(self):
        self.connection_string = os.getenv("AZURE_STORAGE_CONNECTION_STRING")
        self.container_name = os.getenv("AZURE_STORAGE_CONTAINER_NAME", "bird-sounds")
        self.blob_service_client = BlobServiceClient.from_connection_string(self.connection_string)
    
    def create_container_if_not_exists(self):
        try:    
            container_client = self.blob_service_client.get_container_client(self.container_name)
            container_client.get_container_properties()
        except ResourceNotFoundError:
            self.blob_service_client.create_container(self.container_name)
            print(f"Created container: {self.container_name}")

    def upload_sound_file(self, file_path, scientific_name, recording_id=None):
        try:
            # Format: bird-sounds/scientific_name/timestamp_id.mp3
            folder_path = scientific_name.lower().replace(' ', '_')
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            blob_name = f"{folder_path}/{timestamp}_{random.randint(1000, 9999)}.mp3"
            
            if recording_id:
                blob_name = f"{folder_path}/{recording_id}.mp3"
            
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=blob_name
            )

            with open(file_path, "rb") as data:
                blob_client.upload_blob(data)
            return blob_client.url

        except Exception as e:
            print(f"Error uploading file {file_path}: {e}")
            return None