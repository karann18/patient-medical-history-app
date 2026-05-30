from server import app
import json

client = app.test_client()
response = client.get('/api/patients')
print("Status Code:", response.status_code)
print("Response JSON:")
print(json.dumps(response.get_json(), indent=2))
assert response.status_code == 200
print("Verification Succeeded!")
