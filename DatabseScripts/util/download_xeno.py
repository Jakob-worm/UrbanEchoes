import os
import json
import requests
import time
from pathlib import Path
from tqdm import tqdm

def get_xenocanto_download_url(scientific_name):
    """Get download URL for a bird sound from Xeno-Canto"""
    try:
        # Query the Xeno-Canto API
        query = f"https://xeno-canto.org/api/2/recordings?query={scientific_name.replace(' ', '+')}+q:A"
        response = requests.get(query)
        data = response.json()
        
        # Check if we got any recordings
        if data.get('numRecordings', '0') != '0' and data.get('recordings'):
            # Get the first recording info
            recording = data['recordings'][0]
            recording_id = recording.get('id')
            if recording_id:
                download_url = f"https://xeno-canto.org/{recording_id}/download"
                return download_url
    except Exception as e:
        print(f"Error getting Xeno-Canto URL for {scientific_name}: {e}")
    
    return None

def get_xenocanto_download_url_from_recording(recording):
    """Get download URL from a recording object"""
    try:
        recording_id = recording.get('id')
        if recording_id:
            download_url = f"https://xeno-canto.org/{recording_id}/download"
            return download_url
    except Exception as e:
        print(f"Error getting download URL from recording: {e}")
    
    return None

def get_multiple_xenocanto_recordings(scientific_name, count=20):
    """Get multiple high-quality recordings from Xeno-Canto"""
    recordings = []
    try:
        # Query the Xeno-Canto API for high-quality recordings (q:A) 
        query = f"https://xeno-canto.org/api/2/recordings?query={scientific_name.replace(' ', '+')}+q:A"
        response = requests.get(query)
        data = response.json()
        
        # Check if we got any recordings
        if data.get('numRecordings', '0') != '0' and data.get('recordings'):
            # Get the recordings, sort by quality
            all_recordings = data['recordings']
            # Sort by quality rating (A is best)
            all_recordings.sort(key=lambda x: x.get('q', 'E'), reverse=False)
            
            # Take requested number of recordings
            return all_recordings[:count]
    except Exception as e:
        print(f"Error getting Xeno-Canto recordings for {scientific_name}: {e}")
    
    return recordings

def download_sound_file(url, download_dir, recording_id=None):
    """Download sound file from URL and return local path"""
    try:
        if not url:
            return None
            
        # Create directory if it doesn't exist
        os.makedirs(download_dir, exist_ok=True)
        
        # Set default filename
        if recording_id:
            filename = f"{recording_id}.mp3"
        else:
            filename = f"sound_{int(time.time())}.mp3"
            
        local_path = os.path.join(download_dir, filename)
        
        # Download the file
        response = requests.get(url, stream=True)
        response.raise_for_status()
        
        with open(local_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
                
        return local_path
    except Exception as e:
        print(f"Error downloading sound file from {url}: {e}")
        return None

def get_multiple_bird_sounds(scientific_name, temp_dir, count=20):
    """Download multiple sound files for a given bird species"""
    sound_urls = []
    try:
        print(f"Downloading {count} sound recordings for {scientific_name}...")
        # Get best quality recordings sorted by quality
        recordings = get_multiple_xenocanto_recordings(scientific_name, count)
        
        for recording in tqdm(recordings, desc=f"{scientific_name} recordings"):
            if recording and recording.get('file-name') and recording.get('id'):
                download_url = get_xenocanto_download_url_from_recording(recording)
                if download_url:
                    file_path = download_sound_file(download_url, temp_dir, recording['id'])
                    if file_path:
                        sound_urls.append((file_path, recording['id']))
        
        return sound_urls
    except Exception as e:
        print(f"Error downloading sounds for {scientific_name}: {e}")
        return sound_urls