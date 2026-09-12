$run = (Invoke-RestMethod -Uri "https://api.github.com/repos/VIZZARD-X/Attendance/actions/runs").workflow_runs[0]
$runId = $run.id
Write-Host "Waiting for Run ID $runId to finish..."

while ($run.status -ne "completed") {
    Start-Sleep -Seconds 15
    $run = (Invoke-RestMethod -Uri "https://api.github.com/repos/VIZZARD-X/Attendance/actions/runs/$runId")
    Write-Host "Status: $($run.status)..."
}

Write-Host "Deployment completed with conclusion: $($run.conclusion)"
Start-Sleep -Seconds 10

Write-Host "Fetching Azure 500 error trace..."
$token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzg5MjA2MzgzLCJpYXQiOjE3ODkyMDI3ODMsImp0aSI6IjgyYTZiODljOGUzOTRhOGZiODFjZmIwNWFkYjJiY2EwIiwidXNlcl9pZCI6IjIiLCJyb2xlIjoidGVhY2hlciIsInVzZXJuYW1lIjoibXJfdGVhY2hlciJ9.V9rib5CGQllTqwNLurWT-VrFozOoTXeOlIkgzVveASU"
try {
    Invoke-RestMethod -Uri "https://presence-cne6ezafcncnduf3.indiasouthcentral-01.azurewebsites.net/api/v1/classes/2/students/" -Headers @{Authorization="Bearer $token"}
} catch {
    $html = $_.Exception.Response.GetResponseStream() | %{ (New-Object System.IO.StreamReader($_)).ReadToEnd() }
    $html | Select-String -Pattern "Exception|Traceback" -Context 2, 10
    $html | Select-String -Pattern "<pre class=`"exception_value`">" -Context 0, 5
}
