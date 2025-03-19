class BirdObservation:
    def __init__(self, bird_name, scientific_name, sound_directory, latitude, longitude, 
                 observation_date, observation_time, observer_id=0, quantity=1, 
                 is_test_data=False, test_batch_id=None):
        self.bird_name = bird_name
        self.scientific_name = scientific_name
        self.sound_directory = sound_directory
        self.latitude = latitude
        self.longitude = longitude
        self.observation_date = observation_date
        self.observation_time = observation_time
        self.observer_id = observer_id
        self.quantity = quantity
        self.is_test_data = is_test_data
        self.test_batch_id = test_batch_id

    def to_tuple(self):
        """Converts the observation to a tuple for database insertion."""
        return (self.bird_name, self.scientific_name, self.sound_directory, self.latitude, 
                self.longitude, self.observation_date, self.observation_time, self.observer_id, 
                self.quantity, self.is_test_data, self.test_batch_id)
