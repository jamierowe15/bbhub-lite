# BBHub-lite: Business Banking Credit Pipeline on Salesforce

A small version of the kind of CRM + credit platform a bank's business banking team runs on **Salesforce / nCino**. A business applies for credit, Apex scores the risk, a Flow routes the application to the right review tier, a loan officer works the queue in a Lightning Web Component, decisions publish a **Platform Event**, and a subscriber writes an audit log. Everything deploys through a **CI/CD** pipeline with tests.

> Portfolio project with fictional data. It is not affiliated with any bank, and the risk model is not a real credit model.

![stack](https://img.shields.io/badge/Apex-trigger%20%2B%20handler-1F3864) ![stack](https://img.shields.io/badge/LWC-Jest%20tested-1F3864) ![stack](https://img.shields.io/badge/Flow-before--save-1F3864) ![stack](https://img.shields.io/badge/Platform%20Events-pub%2Fsub-1F3864) ![stack](https://img.shields.io/badge/CI-GitHub%20Actions-1F3864)

## What it does

```
 Loan officer (LWC "Loan Pipeline" tab)        REST API client (scripts/api)
              |  @wire / imperative Apex                 |  /services/data/v62.0
              v                                          v
   LoanApplicationController (with sharing, USER_MODE)   |
              |                                          |
              v                                          v
   +--------------------  Loan_Application__c save  ---------------------+
   | 1. Before-save Flow  -> Review_Tier__c (Branch / Senior / Executive) |
   | 2. Before trigger    -> Risk_Score__c, Risk_Rating__c, validation    |
   | 3. After trigger     -> EventBus.publish(Loan_Decision__e)           |
   +---------------------------------------------------------------------+
              |  (published after commit)
              v
   LoanDecisionEventTrigger -> Loan_Decision_Log__c (audit trail)
```

| Job-posting requirement | Where it is in this repo |
|---|---|
| Apex | `classes/LoanRiskService`, `LoanApplicationTriggerHandler`, `LoanApplicationController`, `LoanDecisionEventHandler` |
| Lightning Web Components | `lwc/loanPipeline` (+ Jest tests in `__tests__`) |
| Visualforce (legacy) | `pages/LoanApplicationCreditMemo.page` (PDF credit memo) |
| Salesforce API | `scripts/api/rest-api-demo.ps1` (SOQL over REST, create/read/update, limits) |
| Flows | `flows/Loan_Application_Route_For_Review` (record-triggered, before-save) |
| Triggers | `triggers/LoanApplicationTrigger` (one per object, logic in handler) |
| Platform Events | `objects/Loan_Decision__e` + `triggers/LoanDecisionEventTrigger` |
| Platform limits and governance | Bulkified handler, 200-record bulk test asserting 0 SOQL, aggregate SOQL |
| CI/CD pipelines | `.github/workflows/ci.yml` (Jest + check-only deploy + Apex tests) |
| Banking regulation and security | `with sharing`, `WITH USER_MODE`, `as user` DML, least-privilege permission set, field history, audit log |
| Monitor Apex performance / SOQL efficiency | `Limits.getQueries()` assertions, aggregate queries, no queries in loops |

## Quick start (Windows)

1. Get a free org at **https://developer.salesforce.com/signup** (or use a Trailhead Playground).
2. Unzip this folder, then **double-click `setup.cmd`**.

The script installs anything that's missing (Node.js, Git, Salesforce CLI), logs you in, deploys the project, runs every test, loads demo data, opens the app, and can push the code to GitHub. If a step fails, fix it and resume with `.\setup.ps1 -From <step>`.

Manual equivalent:

```powershell
npm install --global @salesforce/cli
sf org login web --alias bbhub --set-default
sf project deploy start --source-dir force-app --test-level RunLocalTests --wait 30
sf org assign permset --name BBHub_Lite_User
sf apex run --file scripts/apex/seed.apex
sf apex run test --test-level RunLocalTests --code-coverage --result-format human --wait 20
npm install; npm run test:unit
sf org open --path lightning/n/Loan_Pipeline
```

## Tests

| Suite | Count | Runs where |
|---|---|---|
| `LoanRiskServiceTest` | 5 | Org (pure unit tests, no DML) |
| `LoanApplicationTriggerHandlerTest` | 9 | Org (includes 200-record bulk + platform event delivery) |
| `LoanApplicationControllerTest` | 5 | Org (runs as a least-privilege Standard User) |
| `loanPipeline.test.js` | 8 | Your PC / GitHub Actions (Jest) |

## Learn it

Read **[LECTURE.md](LECTURE.md)**. It teaches every concept in this repo from zero, walks through each file, and finishes with interview questions.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `sf` not recognized after install | Close the window, open a new one, run `.\setup.ps1 -From 2` |
| Deploy fails with a test failure | Read the failing test name and message in the output. The deploy is all-or-nothing, so nothing changed in the org. Fix the code and run `.\setup.ps1 -From 4` |
| Deploy error about a tab `motif` | Open `force-app/main/default/tabs/*.tab-meta.xml` and change the motif to another value from Setup > Tabs, or delete the tab files and add the LWC to the Home page with Lightning App Builder |
| Review Tier is blank | The Flow deployed inactive. Setup > Flows > *Loan Application - Route For Review* > Activate |
| No Decision Logs yet | Platform events are asynchronous. Wait a few seconds and refresh |
| "Insufficient access" in the LWC | Run `sf org assign permset --name BBHub_Lite_User` |
