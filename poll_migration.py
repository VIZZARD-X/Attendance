import urllib.request, urllib.error
import time

url = 'https://presence-cne6ezafcncnduf3.indiasouthcentral-01.azurewebsites.net/api/v1/trigger-migration-123/'

print(f"Polling {url} until deployment completes...")
for i in range(30):
    try:
        req = urllib.request.Request(url)
        res = urllib.request.urlopen(req)
        content = res.read().decode('utf-8')
        if "Migration" in content:
            print("Success!")
            print(content)
            break
        else:
            print("Got Flutter index.html, waiting for deployment...")
    except urllib.error.HTTPError as e:
        if e.code == 500:
            content = e.read().decode('utf-8')
            if "Migration Failed" in content:
                print("Migration Failed!")
                print(content)
                break
        print(f"Error {e.code}, waiting...")
    except Exception as e:
        print("Exception:", e)
    
    time.sleep(10)
