<#
===============================================================================
  BBHub-lite  -  one-command setup (Windows PowerShell 5.1+ / PowerShell 7)
===============================================================================
  Double-click setup.cmd, or run:
      powershell -ExecutionPolicy Bypass -File .\setup.ps1

  What it does (each step is safe to re-run):
     1  Check / install prerequisites (Node.js LTS, Git, Salesforce CLI)
     2  Install the VS Code Salesforce Extension Pack (if VS Code is installed)
     3  Log in to your free Salesforce Developer Edition org (opens browser)
     4  Deploy all metadata AND run every Apex test (like a real bank pipeline)
     5  Assign the BBHub_Lite_User permission set to you
     6  Load demo data (fictional businesses + loan applications)
     7  Run Apex tests again with a code-coverage report
     8  Run the LWC Jest tests locally (no org needed)
     9  Show the results (applications, risk ratings, review tiers, audit log)
    10  Open the Loan Pipeline tab in your browser
    11  (Optional) Push to GitHub + wire up the CI secret

  Options:
      -OrgAlias bbhub      alias for your org (default: bbhub)
      -From 4              start at step 4 (skip earlier steps)
      -Only 8              run just one step
      -SkipGitHub          never ask about GitHub
      -GitHubUser name     default: jamierowe15

  A full log is written to setup-log.txt.
===============================================================================
#>
[CmdletBinding()]
param(
    [string]$OrgAlias = 'bbhub',
    [int]$From = 1,
    [int]$Only = 0,
    [switch]$SkipGitHub,
    [string]$GitHubUser = 'jamierowe15',
    [string]$RepoName = 'bbhub-lite'
)

# 'Continue' on purpose: in Windows PowerShell 5.1, 'Stop' turns harmless CLI warnings
# written to stderr into fatal errors. Failures are detected through exit codes instead.
$ErrorActionPreference = 'Continue'
Set-Location -Path $PSScriptRoot
try { Start-Transcript -Path (Join-Path $PSScriptRoot 'setup-log.txt') -Append | Out-Null } catch { }

# ----------------------------------------------------------------- helpers
function Write-Banner([int]$n, [string]$title) {
    Write-Host ''
    Write-Host ('=' * 75) -ForegroundColor DarkCyan
    Write-Host (" STEP {0,2} | {1}" -f $n, $title) -ForegroundColor Cyan
    Write-Host ('=' * 75) -ForegroundColor DarkCyan
}
function Write-Ok([string]$m)   { Write-Host "  [OK]   $m" -ForegroundColor Green }
function Write-Info([string]$m) { Write-Host "  [..]   $m" -ForegroundColor Gray }
function Write-Warn([string]$m) { Write-Host "  [!!]   $m" -ForegroundColor Yellow }
function Write-Fail([string]$m) { Write-Host "  [XX]   $m" -ForegroundColor Red }

function Test-Command([string]$name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }

function Update-SessionPath {
    $machine = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
    $npmGlobal = Join-Path $env:APPDATA 'npm'
    if ((Test-Path $npmGlobal) -and ($env:Path -notlike "*$npmGlobal*")) { $env:Path += ";$npmGlobal" }
}

# Runs an external command, echoes it, and stops the script if it fails.
function Invoke-Native([string]$description, [scriptblock]$command, [switch]$AllowFail) {
    Write-Info $description
    Write-Host "         > $($command.ToString().Trim())" -ForegroundColor DarkGray
    & $command | Out-Host   # stream output to the screen as it happens
    $code = $LASTEXITCODE
    if ($code -ne 0 -and -not $AllowFail) {
        Write-Fail "Command failed (exit code $code)."
        throw "Step failed: $description"
    }
    return $code
}

function Confirm-YesNo([string]$question, [bool]$default = $true) {
    $suffix = if ($default) { '[Y/n]' } else { '[y/N]' }
    $answer = Read-Host "  ?? $question $suffix"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $default }
    return $answer.Trim().ToLower().StartsWith('y')
}

function Test-OrgConnected {
    if (-not (Test-Command 'sf')) { return $false }
    $null = sf org display --target-org $OrgAlias --json 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Test-ShouldRun([int]$n) {
    if ($Only -gt 0) { return ($n -eq $Only) }
    return ($n -ge $From)
}

# ------------------------------------------------------------------- steps
function Step1-Prerequisites {
    Write-Banner 1 'Prerequisites: Node.js, Git, Salesforce CLI'
    $hasWinget = Test-Command 'winget'

    if (Test-Command 'node') { Write-Ok "Node.js $(node -v)" }
    elseif ($hasWinget) {
        Invoke-Native 'Installing Node.js LTS with winget' { winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements }
        Update-SessionPath
    } else { throw 'Node.js is missing. Install the LTS version from https://nodejs.org then re-run setup.' }

    if (Test-Command 'git') { Write-Ok "$(git --version)" }
    elseif ($hasWinget) {
        Invoke-Native 'Installing Git with winget' { winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements }
        Update-SessionPath
    } else { Write-Warn 'Git is missing (only needed for step 11). Get it from https://git-scm.com' }

    if (Test-Command 'sf') {
        Write-Ok "Salesforce CLI: $((sf --version) | Select-Object -First 1)"
    } else {
        Invoke-Native 'Installing the Salesforce CLI (npm install -g @salesforce/cli). This takes a few minutes.' { npm install --global @salesforce/cli }
        Update-SessionPath
        if (-not (Test-Command 'sf')) { throw 'sf was installed but is not on PATH yet. Close this window, open a new one, and run: .\setup.ps1 -From 2' }
        Write-Ok "Salesforce CLI: $((sf --version) | Select-Object -First 1)"
    }
}

function Step2-VSCode {
    Write-Banner 2 'VS Code Salesforce Extension Pack (optional)'
    if (-not (Test-Command 'code')) {
        Write-Warn 'VS Code not found. Optional, but recommended: https://code.visualstudio.com'
        return
    }
    Invoke-Native 'Installing salesforce.salesforcedx-vscode' { code --install-extension salesforce.salesforcedx-vscode --force } -AllowFail | Out-Null
    Write-Ok 'Open this folder in VS Code to get Apex/LWC IntelliSense: code .'
}

function Step3-Login {
    Write-Banner 3 "Connect your Salesforce Developer Edition org (alias '$OrgAlias')"
    if (Test-OrgConnected) {
        $u = (sf org display --target-org $OrgAlias --json | Out-String | ConvertFrom-Json).result.username
        Write-Ok "Already connected as $u"
        return
    }
    Write-Host ''
    Write-Host '  You need a FREE Salesforce Developer Edition org. If you do not have one:' -ForegroundColor White
    Write-Host '    1. Go to  https://developer.salesforce.com/signup' -ForegroundColor White
    Write-Host '    2. Sign up (use a unique username, e.g. jamie.bbhub@yourname.dev)' -ForegroundColor White
    Write-Host '    3. Verify the email and set your password' -ForegroundColor White
    Write-Host '  A Trailhead Playground also works (get its username/password from Trailhead).' -ForegroundColor Gray
    Write-Host ''
    Read-Host '  Press ENTER when you have your login ready (a browser window will open)'
    Invoke-Native 'Opening the Salesforce login page' { sf org login web --alias $OrgAlias --set-default --instance-url https://login.salesforce.com } | Out-Null
    Write-Ok 'Org connected.'
}

function Step4-Deploy {
    Write-Banner 4 'Deploy metadata + run all Apex tests (RunLocalTests)'
    Write-Info 'Production-style deploy: if any Apex test fails or coverage is under 75%, NOTHING is deployed.'
    Invoke-Native 'Deploying force-app' { sf project deploy start --source-dir force-app --target-org $OrgAlias --test-level RunLocalTests --wait 30 } | Out-Null
    Write-Ok 'Deployed: 2 custom objects, 1 platform event, 4 Apex classes + 4 test classes, 2 triggers, 1 Flow, 1 LWC, 1 Visualforce page, tabs, layout, permission set.'
}

function Step5-PermSet {
    Write-Banner 5 'Assign the BBHub_Lite_User permission set'
    $code = Invoke-Native 'Assigning permission set to you' { sf org assign permset --name BBHub_Lite_User --target-org $OrgAlias } -AllowFail
    if ($code -ne 0) { Write-Warn 'Assignment returned an error. If it says it is already assigned, that is fine.' }
    else { Write-Ok 'Permission set assigned.' }
}

function Step6-Seed {
    Write-Banner 6 'Load demo data'
    Invoke-Native 'Running scripts/apex/seed.apex' { sf apex run --file scripts/apex/seed.apex --target-org $OrgAlias } | Out-Null
    Write-Ok 'Demo data loaded (6 fictional businesses, 7 loan applications).'
}

function Step7-ApexTests {
    Write-Banner 7 'Apex tests with code coverage'
    New-Item -ItemType Directory -Force -Path 'test-results' | Out-Null
    Invoke-Native 'Running all local Apex tests' { sf apex run test --test-level RunLocalTests --code-coverage --result-format human --output-dir test-results --wait 20 --target-org $OrgAlias } | Out-Null
    Write-Ok 'Apex tests passed. Detailed results are in .\test-results'
}

function Step8-LwcTests {
    Write-Banner 8 'LWC Jest unit tests (runs locally, no org needed)'
    if (-not (Test-Path 'node_modules')) {
        Invoke-Native 'Installing dev dependencies (npm install)' { npm install --no-audit --no-fund } | Out-Null
    }
    Invoke-Native 'npm run test:unit:coverage' { npm run test:unit:coverage } | Out-Null
    Write-Ok 'LWC tests passed.'
}

function Step9-Show {
    Write-Banner 9 'Results: what your automation did'
    Write-Info 'Loan applications (Risk = Apex trigger, Review Tier = Flow):'
    sf data query --target-org $OrgAlias --query "SELECT Name, Account__r.Name, Requested_Amount__c, Status__c, Risk_Score__c, Risk_Rating__c, Review_Tier__c FROM Loan_Application__c ORDER BY Name"
    Write-Info 'Waiting 10 seconds for the platform event subscriber to write audit logs...'
    Start-Sleep -Seconds 10
    Write-Info 'Decision audit log (written by the Loan_Decision__e platform event trigger):'
    sf data query --target-org $OrgAlias --query "SELECT Name, Loan_Application__r.Name, Decision__c, Requested_Amount__c, Logged_At__c FROM Loan_Decision_Log__c ORDER BY Name"
    Write-Host ''
    Write-Info 'If Review Tier is blank, the Flow deployed as Inactive. Fix: Setup > Flows >'
    Write-Info '"Loan Application - Route For Review" > open it > Activate, then edit any record.'
}

function Step10-Open {
    Write-Banner 10 'Open the Loan Pipeline'
    Invoke-Native 'Opening the Loan Pipeline tab' { sf org open --target-org $OrgAlias --path lightning/n/Loan_Pipeline } -AllowFail | Out-Null
    Write-Host ''
    Write-Host '  Try this in the browser:' -ForegroundColor White
    Write-Host '   - Use the row menu (down arrow) to Approve a Submitted application -> toast + tiles refresh' -ForegroundColor White
    Write-Host '   - Try to Approve a Draft one -> the Apex validation error appears as a red toast' -ForegroundColor White
    Write-Host '   - App Launcher > Loan Applications > open a record > Related > Decision Logs / History' -ForegroundColor White
    Write-Host '   - Credit memo PDF: /apex/LoanApplicationCreditMemo?id=<record Id>' -ForegroundColor White
    Write-Host '   - REST API demo: powershell -ExecutionPolicy Bypass -File scripts\api\rest-api-demo.ps1' -ForegroundColor White
}

function Step11-GitHub {
    Write-Banner 11 'GitHub (optional)'
    if ($SkipGitHub) { Write-Info 'Skipped (-SkipGitHub).'; return }
    if (-not (Test-Command 'git')) { Write-Warn 'Git not installed; skipping.'; return }
    if (-not (Confirm-YesNo "Push this project to github.com/$GitHubUser/$RepoName ?" $true)) { return }

    if (-not (Test-Path '.git')) {
        Invoke-Native 'git init' { git init -b main } | Out-Null
    }
    Invoke-Native 'git add + commit' { git add -A } | Out-Null
    git commit -m 'BBHub-lite: Salesforce business banking credit pipeline (Apex, LWC, Flow, Platform Events, CI)' 2>$null | Out-Null

    if (-not (Test-Command 'gh')) {
        Write-Warn 'GitHub CLI (gh) not found. Install it with: winget install GitHub.cli   then run: .\setup.ps1 -Only 11'
        return
    }
    gh auth status 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Invoke-Native 'Logging in to GitHub' { gh auth login --web --git-protocol https } | Out-Null }

    gh repo view "$GitHubUser/$RepoName" 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Invoke-Native 'Creating the public repo and pushing' { gh repo create "$GitHubUser/$RepoName" --public --source . --remote origin --push --description 'Salesforce business-banking credit pipeline: Apex, LWC, Flow, Platform Events, Visualforce, CI/CD' } | Out-Null
    } else {
        git remote get-url origin 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { git remote add origin "https://github.com/$GitHubUser/$RepoName.git" }
        Invoke-Native 'Pushing to existing repo' { git push -u origin main } | Out-Null
    }
    Write-Ok "Code is on https://github.com/$GitHubUser/$RepoName"

    Write-Host ''
    Write-Host '  CI/CD: GitHub Actions always runs the LWC tests. To also have it validate a' -ForegroundColor White
    Write-Host '  deployment + run Apex tests against your org on every push, it needs a secret' -ForegroundColor White
    Write-Host '  called SFDX_AUTH_URL. That secret gives access to this org, so use it ONLY' -ForegroundColor Yellow
    Write-Host '  with this free practice org, never a real work org.' -ForegroundColor Yellow
    if (Confirm-YesNo 'Set the SFDX_AUTH_URL secret now?' $false) {
        $auth = (sf org display --target-org $OrgAlias --verbose --json | Out-String | ConvertFrom-Json).result.sfdxAuthUrl
        if ([string]::IsNullOrWhiteSpace($auth)) { Write-Warn 'Could not read the auth URL (log in with sf org login web first).'; return }
        $auth | gh secret set SFDX_AUTH_URL --repo "$GitHubUser/$RepoName"
        if ($LASTEXITCODE -eq 0) { Write-Ok 'Secret set. Next push will run the full pipeline.' }
    }
}

# --------------------------------------------------------------------- main
$steps = @(
    @{ n = 1; f = 'Step1-Prerequisites' }, @{ n = 2; f = 'Step2-VSCode' }, @{ n = 3; f = 'Step3-Login' },
    @{ n = 4; f = 'Step4-Deploy' }, @{ n = 5; f = 'Step5-PermSet' }, @{ n = 6; f = 'Step6-Seed' },
    @{ n = 7; f = 'Step7-ApexTests' }, @{ n = 8; f = 'Step8-LwcTests' }, @{ n = 9; f = 'Step9-Show' },
    @{ n = 10; f = 'Step10-Open' }, @{ n = 11; f = 'Step11-GitHub' }
)

Write-Host ''
Write-Host '  BBHub-lite setup  |  Salesforce business-banking credit pipeline' -ForegroundColor White
Write-Host "  Org alias: $OrgAlias   Folder: $PSScriptRoot" -ForegroundColor Gray

$current = 0
try {
    Update-SessionPath
    foreach ($s in $steps) {
        if (Test-ShouldRun $s.n) {
            $current = $s.n
            & $s.f
        }
    }
    Write-Host ''
    Write-Host ('=' * 75) -ForegroundColor Green
    Write-Host '  ALL DONE. Read LECTURE.md next: it explains every file you just deployed.' -ForegroundColor Green
    Write-Host ('=' * 75) -ForegroundColor Green
}
catch {
    Write-Host ''
    Write-Fail $_.Exception.Message
    Write-Host ''
    Write-Host "  Fix the problem above, then resume from this step with:" -ForegroundColor Yellow
    Write-Host "      .\setup.ps1 -From $current" -ForegroundColor Yellow
    Write-Host '  See "Troubleshooting" in README.md. Full log: setup-log.txt' -ForegroundColor Yellow
    exit 1
}
finally {
    try { Stop-Transcript | Out-Null } catch { }
}
