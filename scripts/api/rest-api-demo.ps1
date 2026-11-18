<#
  rest-api-demo.ps1  -  Talk to Salesforce through its REST API (no browser).

  What it shows (this is what "Salesforce API" means on the job posting):
    1. Get an access token + instance URL from the Salesforce CLI
    2. GET   /services/data/vXX.X/query?q=SOQL       -> run SOQL over HTTP
    3. POST  /services/data/vXX.X/sobjects/Loan_Application__c   -> create a record
    4. GET   the new record back by Id  (your Apex trigger has scored it already!)
    5. PATCH it to Submitted
    6. GET   /services/data/vXX.X/limits             -> see API/governor usage

  Run:  powershell -ExecutionPolicy Bypass -File scripts\api\rest-api-demo.ps1
#>
param([string]$OrgAlias = 'bbhub', [string]$ApiVersion = 'v62.0')
$ErrorActionPreference = 'Stop'

Write-Host "`n[1] Getting a session from the Salesforce CLI for '$OrgAlias'..." -ForegroundColor Cyan
$org = (sf org display --target-org $OrgAlias --json | Out-String | ConvertFrom-Json).result
$base = "$($org.instanceUrl)/services/data/$ApiVersion"
$headers = @{ Authorization = "Bearer $($org.accessToken)"; 'Content-Type' = 'application/json' }
Write-Host "    Instance: $($org.instanceUrl)"

Write-Host "`n[2] SOQL over REST: the 5 largest applications" -ForegroundColor Cyan
$soql = 'SELECT Name, Account__r.Name, Requested_Amount__c, Status__c, Risk_Rating__c FROM Loan_Application__c ORDER BY Requested_Amount__c DESC LIMIT 5'
$q = Invoke-RestMethod -Method Get -Headers $headers -Uri "$base/query?q=$([uri]::EscapeDataString($soql))"
$q.records | Select-Object Name, @{n='Business';e={$_.Account__r.Name}}, Requested_Amount__c, Status__c, Risk_Rating__c | Format-Table -AutoSize

Write-Host "[3] POST a new Draft application" -ForegroundColor Cyan
$accountId = (Invoke-RestMethod -Headers $headers -Uri "$base/query?q=$([uri]::EscapeDataString("SELECT Id FROM Account WHERE Name LIKE 'BBHub Demo%' LIMIT 1"))").records[0].Id
$body = @{
    Account__c = $accountId; Requested_Amount__c = 325000; Annual_Revenue__c = 900000
    Existing_Debt__c = 150000; Years_In_Business__c = 6; Credit_Score__c = 705
} | ConvertTo-Json
$created = Invoke-RestMethod -Method Post -Headers $headers -Uri "$base/sobjects/Loan_Application__c" -Body $body
Write-Host "    Created Id: $($created.id)"

Write-Host "`n[4] GET it back. Apex (risk) and Flow (tier) already ran on save:" -ForegroundColor Cyan
$rec = Invoke-RestMethod -Headers $headers -Uri "$base/sobjects/Loan_Application__c/$($created.id)?fields=Name,Status__c,Risk_Score__c,Risk_Rating__c,Review_Tier__c"
$rec | Select-Object Name, Status__c, Risk_Score__c, Risk_Rating__c, Review_Tier__c | Format-List

Write-Host "[5] PATCH status to Submitted" -ForegroundColor Cyan
Invoke-RestMethod -Method Patch -Headers $headers -Uri "$base/sobjects/Loan_Application__c/$($created.id)" -Body (@{ Status__c = 'Submitted' } | ConvertTo-Json) | Out-Null
Write-Host "    Done (HTTP 204 No Content = success)."

Write-Host "`n[6] Org limits (daily API requests)" -ForegroundColor Cyan
$limits = Invoke-RestMethod -Headers $headers -Uri "$base/limits"
Write-Host "    DailyApiRequests remaining: $($limits.DailyApiRequests.Remaining) of $($limits.DailyApiRequests.Max)"

Write-Host "`n[7] Bonus: try to break a business rule through the API (amount = 0)" -ForegroundColor Cyan
try {
    Invoke-RestMethod -Method Post -Headers $headers -Uri "$base/sobjects/Loan_Application__c" -Body (@{ Requested_Amount__c = 0 } | ConvertTo-Json) | Out-Null
} catch {
    Write-Host "    Rejected by the Apex trigger, as expected:" -ForegroundColor Yellow
    Write-Host "    $($_.ErrorDetails.Message)"
}
Write-Host "`nREST demo finished." -ForegroundColor Green
