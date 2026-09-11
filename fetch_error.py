import urllib.request, urllib.error, json

try:
    req = urllib.request.Request('https://presence-cne6ezafcncnduf3.indiasouthcentral-01.azurewebsites.net/api/v1/auth/token/', data=json.dumps({'email':'teacher@example.com','password':'password123'}).encode(), headers={'Content-Type': 'application/json'})
    res = urllib.request.urlopen(req)
    token = json.loads(res.read())['access']
    
    req2 = urllib.request.Request('https://presence-cne6ezafcncnduf3.indiasouthcentral-01.azurewebsites.net/api/v1/analytics/teacher/overview/', headers={'Authorization': 'Bearer ' + token})
    urllib.request.urlopen(req2)
except urllib.error.HTTPError as e:
    body = e.read().decode('utf-8')
    # If it's a Django debug page, let's look for the exception value
    import re
    match = re.search(r'<div class="exception_value">(.*?)</div>', body)
    if match:
        print("EXCEPTION:", match.group(1))
    else:
        print("ERROR_BODY:", body[:1000])
