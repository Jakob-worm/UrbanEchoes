from datetime import datetime
import os
import requests


class downloadXeno:
    def get_xenocanto_download_url(scientific_name):
        """Get download URL from Xeno-Canto API"""
        try:
            query = f"{scientific_name} q:A"
            api_url = f'https://xeno-canto.org/api/2/recordings?query={query}'
            print(f'Fetching from Xeno-Canto API: {api_url}')
            
            response = requests.get(api_url)
            if response.status_code == 200:
                data = response.json()
                if int(data['numRecordings']) > 0 and data['recordings']:
                    recording = data['recordings'][0]
                    file_url = recording['file']
                    
                    # Fix URL format
                    if file_url.startswith('//'):
                        file_url = f'https:{file_url}'
                    elif file_url.startswith('https:https://'):
                        file_url = file_url.replace('https:https://', 'https://')
                    
                    print(f'Found recording: {recording["id"]} - Quality: {recording["q"]}')
                    print(f'Download URL: {file_url}')
                    return file_url
            return None
        except Exception as e:
            print(f'Error fetching from Xeno-Canto API: {e}')
            return None

    def download_sound_file(url, temp_dir):
        """Download sound file from Xeno-Canto"""
        try:
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.81 Safari/537.36',
                'Accept': '*/*',
                'Referer': 'https://xeno-canto.org/'
            }
            
            response = requests.get(url, headers=headers, stream=True)
            if response.status_code == 200:
                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                filename = f'temp_bird_{timestamp}.mp3'
                filepath = os.path.join(temp_dir, filename)
                
                with open(filepath, 'wb') as f:
                    for chunk in response.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)
                return filepath
            return None
        except Exception as e:
            print(f'Error downloading file: {e}')
            return None