import requests
import json

base_url = "https://attendance-m2u0.onrender.com/api/v1"

# 1. Login to get token
login_data = {
    "email": "student@example.com",
    "password": "password123"
}

print("Logging in as student...")
response = requests.post(f"{base_url}/auth/token/", json=login_data)
if response.status_code != 200:
    print("Login failed:", response.text)
    exit(1)

token = response.json().get('access')
headers = {"Authorization": f"Bearer {token}"}

# 2. Fetch active sessions
print("Fetching student active sessions...")
sessions_resp = requests.get(f"{base_url}/sessions/student-active/", headers=headers)
if sessions_resp.status_code != 200:
    print("Fetch failed:", sessions_resp.text)
    exit(1)

data = sessions_resp.json()
print("RESPONSE JSON:")
print(json.dumps(data, indent=2))
