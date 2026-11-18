# BBHub-lite Lecture: Salesforce Development for Business Banking, from Zero

**Target role:** TD Associate Software Engineer (nCino/Salesforce), Business Banking Platform, Credit & Sales Modernization (BBHub)
**Project:** BBHub-lite (this repo)
**How to use this file:** Read it top to bottom once (about 3 to 4 hours). Every concept points to the exact file in this project that uses it, so open the file and read along. Part 9 has hands-on labs and Part 10 has interview questions.

---

## Table of Contents

- [Part 0: The job, the team, and what you are building](#part-0-the-job-the-team-and-what-you-are-building)
- [Part 1: Salesforce platform fundamentals](#part-1-salesforce-platform-fundamentals)
- [Part 2: Salesforce DX: the developer toolchain](#part-2-salesforce-dx-the-developer-toolchain)
- [Part 3: The data model (objects and fields)](#part-3-the-data-model-objects-and-fields)
- [Part 4: Apex](#part-4-apex)
- [Part 5: Automation: triggers, Flows, Platform Events](#part-5-automation-triggers-flows-platform-events)
- [Part 6: User interfaces: Lightning Web Components and Visualforce](#part-6-user-interfaces-lightning-web-components-and-visualforce)
- [Part 7: Salesforce APIs and integration](#part-7-salesforce-apis-and-integration)
- [Part 8: Testing, CI/CD, monitoring and production support](#part-8-testing-cicd-monitoring-and-production-support)
- [Part 9: Hands-on labs](#part-9-hands-on-labs)
- [Part 10: Interview preparation](#part-10-interview-preparation)
- [Part 11: Cheat sheet and glossary](#part-11-cheat-sheet-and-glossary)

---

# Part 0: The job, the team, and what you are building

## 0.1 What the posting is really asking for

Translate each line of the posting into plain English:

| Posting says | It means | You practise it in |
|---|---|---|
| Build scalable Salesforce solutions using Apex, LWC, Visualforce (legacy), Salesforce API | Write backend code (Apex), UI (LWC), maintain old pages (Visualforce), integrate with other systems | Parts 4, 6, 7 |
| Implement automation using Flows, Triggers and Platform Events | Make things happen automatically when data changes | Part 5 |
| Follow Salesforce platform limits and governance | Write code that respects governor limits and team standards | 4.6, 4.7 |
| Work with CI/CD pipelines for Salesforce deployments | Code moves through Git, automated tests and automated deploys | 8.3 |
| Banking regulations, internal security, protect customer financial data | Sharing, CRUD/FLS, least privilege, audit trails, no data leaks | 1.5, 4.9 |
| Monitor and improve Apex performance, SOQL efficiency, Governor limit usage | Find slow code, fix bad queries, stay within limits | 4.6, 4.8, 8.4 |
| Troubleshoot production issues | Read debug logs, reproduce, fix, deploy hotfixes | 8.5 |
| GitHub, VS Code, JIRA, Confluence | Daily tools: Git for code, VS Code for editing, JIRA for tickets, Confluence for docs | 2.x, 8.3 |

## 0.2 What is BBHub? What is nCino?

- **Salesforce** is a cloud CRM *platform*. Companies build their own apps on it: custom objects (tables), automation, UIs and APIs. No servers to manage.
- **nCino** is a banking software company whose product is built *natively on Salesforce*. It is installed into a bank's Salesforce org as a **managed package**: pre-built objects, Apex and UIs for commercial lending (loan origination, credit analysis, covenants, document management). nCino components carry their own **namespace prefix**, so you will see names like `LLC_BI__Loan__c` next to the bank's own custom objects.
- **BBHub** (from the posting) is TD Business Banking's integrated **CRM + credit platform**. Relationship managers sell to businesses (CRM side), and credit teams assess and approve loans (credit side). The program modernizes both.

**Your job as an Associate Engineer:** extend and integrate that platform with Apex, LWC, Flows and Platform Events, inside strict limits and security rules.

## 0.3 What BBHub-lite does

BBHub-lite is a miniature credit pipeline built in the same way:

```
Business (Account) --applies--> Loan_Application__c
        |
        |  on save (same transaction):
        |    Flow (before-save)     -> Review_Tier__c        (Branch / Senior / Executive)
        |    Apex before trigger    -> Risk_Score__c, Risk_Rating__c, validation rules
        |    Apex after trigger     -> publish Loan_Decision__e when Approved/Declined
        |
        |  after commit (asynchronous):
        |    Platform event trigger -> Loan_Decision_Log__c  (audit trail)
        |
Loan officer UI: "Loan Pipeline" LWC tab (tiles + work queue + Approve/Decline)
Legacy UI: Visualforce PDF credit memo
Integration: REST API demo script
Delivery: GitHub Actions CI (Jest + check-only deploy + Apex tests)
```

**Status lifecycle (enforced in Apex):**

```
Draft --> Submitted --> Credit Review --> Approved
              \               \--------> Declined
               \-----------------------> Approved / Declined
(Approved and Declined are final. You cannot create a record as Approved.)
```

---

# Part 1: Salesforce platform fundamentals

## 1.1 Multi-tenancy: why Salesforce feels different

Salesforce runs thousands of companies (tenants) on **shared** infrastructure. Your code runs on the same servers as other banks' code. Two consequences shape everything you do:

1. **Governor limits.** The platform caps what one transaction can do (queries, records, CPU time, memory) so no tenant can hog shared resources. Exceed a limit and the transaction dies with an exception you **cannot catch**. (See 4.6.)
2. **Metadata-driven.** Your app is not files on a server. It is *metadata* (definitions of objects, fields, code, pages) stored in the platform. You deploy metadata, and Salesforce compiles and runs it.

## 1.2 Orgs and environments

An **org** is one Salesforce instance (one tenant): its own data, users and metadata.

| Org type | Used for | In this project |
|---|---|---|
| **Production** | Real users and real customer data | Never touched by you directly |
| **Sandbox** (Developer, Dev Pro, Partial, Full) | Copies of production for dev, QA and UAT | At TD you will work in sandboxes |
| **Developer Edition** | Free personal org for learning | **What you use for BBHub-lite** |
| **Scratch org** | Short-lived org created from config (needs Dev Hub) | Mentioned only |
| **Trailhead Playground** | Free org attached to Trailhead | Also works for this project |

A typical bank pipeline: **Dev sandbox -> SIT (integration) -> UAT (business testing) -> Pre-prod/Staging -> Production.**

## 1.3 Declarative vs programmatic ("clicks vs code")

- **Declarative (clicks):** objects, fields, page layouts, validation rules, Flows, permission sets. Admins and BAs can maintain them.
- **Programmatic (code):** Apex, LWC, Visualforce, APIs.

Rule of thumb that interviewers like: **use clicks when they do the job cleanly; use code when you need complex logic, high volume, reusable services or integration.** BBHub-lite uses both on purpose: the Flow does simple routing, Apex does the scoring and validation logic.

## 1.4 Objects, fields, records

| Database word | Salesforce word | Example |
|---|---|---|
| Table | **Object** (sObject) | `Account` (standard), `Loan_Application__c` (custom) |
| Column | **Field** | `Requested_Amount__c` |
| Row | **Record** | LA-0001 |
| Primary key | **Id** (15 or 18 characters) | `a01Ak00000XyZ12AAB` |
| Foreign key | **Lookup** or **Master-Detail** relationship | `Account__c` |

- Custom objects and fields end in **`__c`**. Platform events end in **`__e`**. Relationship names used in SOQL end in **`__r`** (`Account__r.Name`).
- **Lookup vs Master-Detail:**
  - *Lookup:* loose link. The child can exist without the parent and has its own owner and sharing. Used here (`Account__c`, `Loan_Application__c` on the log).
  - *Master-Detail:* tight link. The child is deleted with the parent, inherits sharing, and enables roll-up summary fields.

## 1.5 The security model (critical for banking)

Think of four layers. A user sees a field value only if **every** layer allows it:

```
1. Org access      : can the user log in at all? (IP ranges, login hours, MFA)
2. Object (CRUD)   : can they Create / Read / Edit / Delete this object?
3. Field (FLS)     : can they Read / Edit this field?
4. Record (sharing): can they see THIS record?
     - OWD (org-wide default): Private / Public Read Only / Public Read/Write
     - Role hierarchy: managers see their team's records
     - Sharing rules, teams, manual shares
```

- **Profiles** give each user a baseline. **Permission sets** add permissions on top. Modern best practice is to keep profiles minimal and grant access through permission sets (least privilege).
- In this project, `permissionsets/BBHub_Lite_User.permissionset-meta.xml` grants:
  - Read/Create/Edit on `Loan_Application__c` (no Delete, no View All)
  - **Read-only** on the automation-owned fields (`Risk_Score__c`, `Risk_Rating__c`, `Review_Tier__c`, `Decision_Date__c`), so users cannot fake a risk score
  - Read-only on the audit log `Loan_Decision_Log__c`
  - Access to the Apex controller class, the Visualforce page and the tabs
- **Field History Tracking** is on for `Status__c` and `Requested_Amount__c` (`<trackHistory>true</trackHistory>`). Auditors can see who changed what and when.

Why banks care: privacy law (PIPEDA in Canada), the regulator OSFI (for example Guideline B-13 on technology and cyber risk), and internal audit all expect least privilege, audit trails and protection of customer financial data. In code reviews, "does this enforce CRUD/FLS and sharing?" is a standard question.

---

# Part 2: Salesforce DX: the developer toolchain

## 2.1 Tools

| Tool | What for |
|---|---|
| **Salesforce CLI (`sf`)** | Log in, deploy, retrieve, run tests, run Apex, query data. Everything in `setup.ps1` uses it. |
| **VS Code + Salesforce Extension Pack** | Syntax highlighting, IntelliSense, deploy-on-save, Apex Replay Debugger |
| **Git + GitHub** | Version control, pull requests, CI |
| **Node.js + Jest** | Running LWC unit tests locally |
| **Developer Console** (in the org) | Quick debug logs, query editor, anonymous Apex |

## 2.2 Project structure (source format)

```
bbhub-lite/
├── sfdx-project.json        <- marks this as a Salesforce DX project, sets API version 62.0
├── .forceignore             <- files the CLI must NOT deploy (Jest tests, docs)
├── force-app/main/default/  <- ALL metadata lives here
│   ├── objects/             <- objects, fields, list views (one XML per field)
│   ├── classes/             <- Apex classes (.cls + .cls-meta.xml)
│   ├── triggers/            <- Apex triggers
│   ├── flows/               <- Flow definitions (XML)
│   ├── lwc/                 <- Lightning Web Components (folder per component)
│   ├── pages/               <- Visualforce pages
│   ├── permissionsets/, tabs/, layouts/
├── scripts/apex/seed.apex   <- Anonymous Apex for demo data
├── scripts/api/             <- REST API demo
├── .github/workflows/ci.yml <- CI/CD pipeline
├── setup.cmd / setup.ps1    <- one-click setup
└── package.json, jest.config.js <- LWC testing
```

Every piece of code has a **`-meta.xml`** companion that holds its API version and status. The **API version** (62.0 here) pins the behaviour of that component to a specific Salesforce release. Salesforce ships three releases a year (Spring, Summer, Winter) and each one adds a new API version.

## 2.3 The commands you will use every day

```powershell
sf org login web --alias bbhub --set-default             # authenticate (OAuth in browser)
sf org list                                              # see connected orgs
sf project deploy start --source-dir force-app           # deploy local -> org
sf project retrieve start --metadata ApexClass:MyClass   # pull org -> local
sf project deploy validate --source-dir force-app --test-level RunLocalTests  # check-only deploy
sf apex run test --test-level RunLocalTests --code-coverage --result-format human
sf apex run --file scripts/apex/seed.apex                # anonymous Apex
sf data query --query "SELECT Id, Name FROM Account LIMIT 5"
sf apex tail log                                         # stream debug logs live
sf org open --path lightning/n/Loan_Pipeline
```

---

# Part 3: The data model (objects and fields)

Open `force-app/main/default/objects/`.

## 3.1 `Loan_Application__c`

| Field | Type | Who sets it | Why |
|---|---|---|---|
| Name | Auto Number `LA-{0000}` | Platform | Human-friendly application number |
| `Account__c` | Lookup(Account) | User | The business customer |
| `Requested_Amount__c` | Currency(16,2) | User | Credit requested. **History tracked** |
| `Annual_Revenue__c`, `Existing_Debt__c` | Currency | User | Inputs for leverage |
| `Years_In_Business__c`, `Credit_Score__c` | Number | User | Risk inputs (credit score uses the Canadian 300-900 range) |
| `Status__c` | Picklist (restricted) | User / Apex rules | Lifecycle. **History tracked** |
| `Risk_Score__c`, `Risk_Rating__c` | Number / Picklist | **Apex** | Output of `LoanRiskService` |
| `Review_Tier__c` | Text | **Flow** | Who reviews it |
| `Decision_Date__c` | Date/Time | **Apex** | Stamped on decision |

Look at `objects/Loan_Application__c/fields/Status__c.field-meta.xml`. `<restricted>true</restricted>` means the API cannot insert a value that is not in the list. That is data integrity enforced by the platform.

## 3.2 `Loan_Decision__e` (platform event)

Not a table. It is a **message**. It has fields like an object, but you cannot query it with SOQL or update it. You *publish* it and subscribers *receive* it. `<publishBehavior>PublishAfterCommit</publishBehavior>` is explained in 5.4.

## 3.3 `Loan_Decision_Log__c`

An audit trail written by the event subscriber. `sharingModel` is `Read`, so everyone can read the logs, and only automation writes them.

## 3.4 Supporting metadata

- `layouts/...Loan Application Layout`: which fields appear on the record page, grouped in sections. Automation fields are `Readonly`.
- `listViews/All`: the "All" list on the object tab.
- `tabs/`: one tab for the object, one tab hosting the LWC (`lwcComponent`).

---

# Part 4: Apex

## 4.1 What Apex is

Apex is Salesforce's server-side language. It is **strongly typed, object-oriented and Java-like**, compiled and run on Salesforce servers. It has database access built in: SOQL queries and DML statements are part of the language.

```apex
// variables and types
Integer count = 5;
Decimal amount = 150000.00;     // use Decimal for money
String name = 'Maple Leaf Bakery';
Boolean ok = true;
Id recordId = '001000000000001AAA';
Date today = Date.today();
Datetime now = System.now();

// collections
List<String> statuses = new List<String>{ 'Draft', 'Submitted' };
Set<String> unique = new Set<String>(statuses);
Map<Id, Account> byId = new Map<Id, Account>([SELECT Id, Name FROM Account LIMIT 10]);

// sObjects are typed records
Loan_Application__c app = new Loan_Application__c(Requested_Amount__c = 50000);
app.Status__c = 'Draft';
```

Things that differ from Java:
- **String comparison with `==` is case-insensitive.** `'abc' == 'ABC'` is `true`.
- **Uninitialized variables are `null`**, including Integers and Booleans.
- **No user threads.** Concurrency comes from async Apex (4.10).
- Every transaction is wrapped by the platform, which **commits** at the end or **rolls back everything** if an uncaught exception occurs.

## 4.2 SOQL: Salesforce Object Query Language

SOQL is SQL-like, but read-only and object-oriented.

```apex
// basic, with a bind variable (:status), which is SAFE from injection
List<Loan_Application__c> apps = [
    SELECT Id, Name, Requested_Amount__c
    FROM Loan_Application__c
    WHERE Status__c = :status
    ORDER BY CreatedDate DESC
    LIMIT 200
];

// child -> parent (dot notation through __r)
SELECT Name, Account__r.Name, Account__r.Industry FROM Loan_Application__c

// parent -> children (subquery using the relationship name)
SELECT Name, (SELECT Name, Decision__c FROM Decision_Logs__r) FROM Loan_Application__c

// aggregate
SELECT Status__c stage, COUNT(Id) cnt, SUM(Requested_Amount__c) amt
FROM Loan_Application__c
GROUP BY Status__c
```

There are no `SELECT *` and no arbitrary joins. You traverse relationships instead. See `LoanApplicationController.getPipelineSummary()`: **one aggregate query** returns counts and totals per status, instead of loading every record and counting in a loop. This is the kind of "SOQL efficiency" the posting means.

**SOQL injection:** never build a query by gluing user input into a string:

```apex
// BAD: a user could type   x' OR Name != '
String q = 'SELECT Id FROM Account WHERE Name = \'' + userInput + '\'';
// GOOD: bind variable
List<Account> a = [SELECT Id FROM Account WHERE Name = :userInput];
// If you must use dynamic SOQL, use Database.queryWithBinds(...) or String.escapeSingleQuotes(userInput).
```

## 4.3 DML: writing data

```apex
insert app;            // all-or-nothing: one bad record = exception, whole statement fails
update apps;
delete oldRecords;
upsert apps External_Id__c;

// partial success: bad records fail, good records save
Database.SaveResult[] results = Database.insert(apps, false);
for (Database.SaveResult r : results) {
    if (!r.isSuccess()) System.debug(r.getErrors()[0].getMessage());
}

// user mode DML: enforces the running user's CRUD/FLS/sharing
update as user app;
```

The tests in `LoanApplicationTriggerHandlerTest` use `Database.insert(app, false)` so they can **inspect** validation errors instead of crashing.

## 4.4 Classes, static and the sharing keywords

```apex
public with sharing class LoanApplicationController { ... }      // respects record sharing
public without sharing class LoanDecisionEventHandler { ... }    // system context, ignores sharing
public inherited sharing class Util { ... }                      // takes the caller's mode
```

- **`with sharing`:** queries return only records the user can see. Default for anything user-facing.
- **`without sharing`:** sees everything. Only use it with a written reason. In this project it is the audit-log writer, because an audit log must always be written. Code reviewers at a bank will ask why.
- `static` members belong to the class. Within **one transaction**, static variables persist across trigger invocations, which is why `LoanApplicationTriggerHandler.bypass` works as a switch.

> **Important:** sharing keywords control *record visibility* only. They do **not** enforce CRUD/FLS. For that, see 4.9.

## 4.5 Exceptions

```apex
try {
    update as user app;
} catch (DmlException e) {
    String friendly = e.getDmlMessage(0);
} catch (Exception e) {
    // generic
} finally { }
```

- `AuraHandledException` is the exception to throw from `@AuraEnabled` methods. Its message reaches the LWC safely. See `LoanApplicationController.buildError()`.
- **`LimitException` (governor limit) cannot be caught.** You have to design so you never hit it.

## 4.6 Governor limits (memorize the top six)

Per **transaction** (synchronous / asynchronous):

| Limit | Sync | Async |
|---|---|---|
| **SOQL queries issued** | **100** | 200 |
| **Records retrieved by SOQL** | **50,000** | 50,000 |
| **DML statements** | **150** | 150 |
| **Records processed by DML** | **10,000** | 10,000 |
| **CPU time** | **10,000 ms** | 60,000 ms |
| **Heap size** | **6 MB** | 12 MB |
| Callouts (HTTP) | 100 | 100 |
| `@future` calls | 50 | 0 in batch/future |
| Queueable jobs enqueued | 50 | 1 |

`EventBus.publish()` counts against the DML statement limit, which is one more reason to publish once per batch.

You can check usage in code:

```apex
System.debug('Queries used: ' + Limits.getQueries() + ' / ' + Limits.getLimitQueries());
System.debug('CPU ms: ' + Limits.getCpuTime() + ' / ' + Limits.getLimitCpuTime());
```

The bulk test `bulkApprovalPublishesEventsAndWritesLogs` asserts that **zero** SOQL queries ran while updating 200 records.

## 4.7 Bulkification: the most important habit

Triggers receive records in **batches of up to 200** (Data Loader, API and integrations send many at once). Code that works for 1 record but runs a query per record dies at record 101.

```apex
// BAD: SOQL inside a loop -> 200 records = 200 queries -> LimitException at #101
for (Loan_Application__c app : Trigger.new) {
    Account a = [SELECT Industry FROM Account WHERE Id = :app.Account__c];
    if (a.Industry == 'Agriculture') { app.Review_Tier__c = 'Ag Specialist'; }
}

// GOOD: collect Ids -> ONE query -> Map lookup in the loop
Set<Id> accountIds = new Set<Id>();
for (Loan_Application__c app : Trigger.new) {
    if (app.Account__c != null) accountIds.add(app.Account__c);
}
Map<Id, Account> accounts = new Map<Id, Account>(
    [SELECT Id, Industry FROM Account WHERE Id IN :accountIds]
);
for (Loan_Application__c app : Trigger.new) {
    Account a = accounts.get(app.Account__c);
    if (a != null && a.Industry == 'Agriculture') { app.Review_Tier__c = 'Ag Specialist'; }
}
```

The pattern: **collect -> query once -> map -> loop.** It applies to DML too: build a list, then run **one** `insert` after the loop (see `LoanDecisionEventHandler`).

## 4.8 Query performance (SOQL efficiency)

- **Selective queries:** filter on **indexed** fields (Id, Name, lookups/master-detail, External Ids, unique fields, CreatedDate, SystemModstamp). On large objects (hundreds of thousands of rows or more) a non-selective filter in a trigger can throw "Non-selective query against large object type".
- Avoid leading wildcards (`LIKE '%abc'`), negative filters (`!=`, `NOT IN`), and filters on formula fields where you can.
- Select only the fields you need, and always `LIMIT` UI queries (`MAX_ROWS = 200` in the controller).
- Use the **Query Plan** tool (Developer Console > Preferences > Enable Query Plan) to see the cost and whether an index is used.
- Use aggregates instead of counting in Apex.

## 4.9 Enforcing CRUD and FLS in Apex (the banking topic)

Apex runs in **system mode** by default: it ignores the user's object and field permissions. For user-facing code you must enforce them:

| Technique | Example | Notes |
|---|---|---|
| **`WITH USER_MODE`** (recommended) | `SELECT ... FROM X WITH USER_MODE` | Enforces CRUD, FLS and sharing; throws if a field is not accessible |
| **`as user` DML** | `update as user app;` | Same, for writes |
| `Security.stripInaccessible()` | `Security.stripInaccessible(AccessType.READABLE, records)` | Silently removes inaccessible fields instead of throwing |
| `WITH SECURITY_ENFORCED` | older syntax | Superseded by USER_MODE |
| Schema describe checks | `Schema.sObjectType.Account.isUpdateable()` | Manual, verbose |

`LoanApplicationController` uses `WITH USER_MODE` on every query and `update as user` on the write. `LoanApplicationControllerTest` runs **as a Standard User with only the permission set**, which proves the permission set grants exactly enough.

Other protections for customer financial data:
- Never `System.debug()` sensitive values (SIN, account numbers). Debug logs can be read by admins.
- Validate inputs against an allow-list (`ALLOWED_TARGET_STATUSES`).
- Return generic error messages. Don't leak stack traces.
- Platform features banks use: **Shield Platform Encryption** (encryption at rest), **Event Monitoring** (who exported what), **Field Audit Trail** (long-term history), **Transaction Security** policies.

## 4.10 Asynchronous Apex (interview favourite)

| Type | Use when | Key facts |
|---|---|---|
| `@future` | Simple fire-and-forget, callouts from triggers | Primitive params only, no chaining |
| **Queueable** | Most async work | Can pass sObjects, can chain, returns a job Id |
| **Batch Apex** | Millions of records (nightly recalcs) | `start` / `execute` (chunks of up to 2,000, default 200) / `finish` |
| Schedulable | Run on a schedule | Often starts a batch |
| Platform Event trigger | Decoupled event-driven processing | What this project uses |

---

# Part 5: Automation: triggers, Flows, Platform Events

## 5.1 Triggers

A trigger is Apex that runs when records are saved.

```apex
trigger LoanApplicationTrigger on Loan_Application__c (before insert, before update, after update) {
    LoanApplicationTriggerHandler.handle(Trigger.operationType, Trigger.new, Trigger.oldMap);
}
```

**Before vs after:**
- **Before** triggers change field values on `Trigger.new` directly, with **no DML needed** because the platform saves them. Use them for defaults, calculations and validation (`addError`).
- **After** triggers run when the record has an Id and is saved (not yet committed). Use them to work with *other* records, publish events, or anything that needs the Id. `Trigger.new` is read-only here.

**Context variables:** `Trigger.new`, `Trigger.old`, `Trigger.newMap`, `Trigger.oldMap`, `Trigger.isInsert/isUpdate/isDelete`, `Trigger.isBefore/isAfter`, `Trigger.size`, `Trigger.operationType`.
`Trigger.old` doesn't exist on insert, and `Trigger.newMap` doesn't exist in *before insert* (no Ids yet).

**Best practices (all applied here):**
1. **One trigger per object.** With several triggers on one object, the execution order is not guaranteed.
2. **No logic in the trigger.** Delegate to a handler class.
3. **Bulkify** (4.7).
4. **Detect real changes:** `app.Status__c != oldApp.Status__c` so you only act on actual transitions.
5. **Bypass switch** for data migrations (`LoanApplicationTriggerHandler.bypass`).
6. **Guard against recursion:** if an after trigger updates the same object, use a static flag or a Set of processed Ids.

### Walkthrough: `LoanApplicationTriggerHandler.cls`

- `switch on operation` routes each context to small private methods.
- `setDefaults` puts blank statuses to Draft.
- `LoanRiskService.applyRisk(newList)` scores in memory. No SOQL, no DML.
- `validate`:
  - `app.addError(Loan_Application__c.Requested_Amount__c, '...')` marks **that one record** as failed and shows the message next to the field in the UI. Other records in the batch still save.
  - Enforces the lifecycle (cannot create as Approved, only decide from Submitted/Credit Review, decided records are final).
- `stampDecisionDate` sets `Decision_Date__c` in *before update*, so no extra DML.
- `publishDecisionEvents` (after update) builds a list and calls `EventBus.publish(events)` **once**.

### Walkthrough: `LoanRiskService.cls`

A pure function: inputs in, score out. Three factors (credit score, leverage = (debt + request) / revenue, time in business), capped at 100, mapped to Low (< 35), Medium (35-59) and High (60+). Because it has no database access, `LoanRiskServiceTest` tests it in memory, which is fast and simple. Separating **logic** (service) from **orchestration** (handler) is the pattern senior engineers look for.

## 5.2 Order of execution (simplified, worth memorizing)

When a record is saved:

```
 1. Load the record, apply new values, system validation (required fields, field formats)
 2. BEFORE-SAVE record-triggered FLOWS      <- our Flow sets Review_Tier__c
 3. BEFORE TRIGGERS                         <- our handler scores risk + validates
 4. System validation again + custom VALIDATION RULES
 5. Duplicate rules
 6. Record saved to the database (NOT committed yet)
 7. AFTER TRIGGERS                          <- our handler publishes events
 8. Assignment rules, auto-response rules, workflow rules (legacy), escalation rules
 9. AFTER-SAVE record-triggered FLOWS
10. Roll-up summaries, sharing recalculation
11. COMMIT
12. Post-commit: emails, async jobs, PUBLISH-AFTER-COMMIT EVENTS <- our Loan_Decision__e goes out
```

Interview tip: before-save Flows run **before** before-triggers. So in BBHub-lite the Flow has already set `Review_Tier__c` when Apex runs.

## 5.3 Flows

Flow Builder is Salesforce's declarative automation tool. Main types:

| Type | Starts when | Example |
|---|---|---|
| **Record-triggered** (before-save) | A record is created/updated, before it saves | Set fields on the same record. Fastest, no DML |
| Record-triggered (after-save) | After save | Create/update related records, send emails, call actions |
| Screen Flow | User clicks a button/page | Guided wizards (loan intake forms) |
| Schedule-triggered | On a schedule | Nightly clean-up |
| Autolaunched | Called from Apex, another Flow or the API | Reusable sub-processes |
| Platform-event-triggered | An event arrives | React to `Loan_Decision__e` declaratively |

### Walkthrough: `flows/Loan_Application_Route_For_Review.flow-meta.xml`

- `<triggerType>RecordBeforeSave</triggerType>` + `<recordTriggerType>CreateAndUpdate</recordTriggerType>`
- A **Decision** element `Route_By_Amount` with outcomes: over $1M -> "Executive Credit Committee", over $250K -> "Senior Credit Analyst", default -> "Branch Lending".
- **Assignment** elements write to `$Record.Review_Tier__c`. `$Record` is the record being saved.
- Open it in the org: Setup > Flows > *Loan Application - Route For Review*. Seeing the canvas makes the XML make sense.

**Flow vs Apex: how to choose (likely interview question):**
- Flow: simple field updates, routing, notifications, screens, logic that BAs or admins should own.
- Apex: complex calculations, large volumes, heavy collection logic, integrations and callouts with error handling, anything that needs unit tests at the code level.
- Avoid having a Flow and a trigger update the *same* field. Here they own different fields on purpose.

## 5.4 Platform Events (event-driven architecture)

A platform event is a **message on a bus**. Publishers don't know who is listening, and subscribers don't know who published. This **decoupling** is how large banks connect Salesforce to core banking, document systems, data warehouses and notification services.

```
Publisher (Apex/Flow/API) --> [ Event Bus: Loan_Decision__e ] --> Subscriber: Apex trigger
                                                              --> Subscriber: Flow
                                                              --> Subscriber: external system (Pub/Sub API)
                                                              --> Subscriber: LWC (empApi)
```

Key concepts:
- **Publish behaviour:**
  - `PublishAfterCommit`: sent only if the transaction succeeds. **Used here**, because you must never announce a loan decision that rolled back.
  - `PublishImmediately`: sent even if the transaction later fails. Good for logging errors.
- **High-volume** events are stored on the bus for **72 hours**, and subscribers can replay from a `ReplayId` after an outage.
- **Platform event triggers** only support `after insert`, run **asynchronously** as the **Automated Process** user, and receive batches of up to **2,000** events, so you bulkify them too.
- Events are not queryable with SOQL and cannot be updated or deleted.
- Related feature: **Change Data Capture (CDC)** publishes events automatically whenever records change, with no code. Platform Events carry the *business* events you define.

### Testing events

```apex
Test.startTest();
update apps;           // trigger publishes events
Test.stopTest();       // events are delivered to subscribers here
// or call Test.getEventBus().deliver(); to deliver mid-test
```

---

# Part 6: User interfaces: Lightning Web Components and Visualforce

## 6.1 LWC basics

LWC is Salesforce's modern UI framework, built on **standard web components** (HTML, JavaScript, CSS). A component is a folder:

```
lwc/loanPipeline/
  loanPipeline.html        <- template
  loanPipeline.js          <- logic (ES module class)
  loanPipeline.css         <- styles, scoped to this component (Shadow DOM)
  loanPipeline.js-meta.xml <- where it can be used (tab, app page, home page)
  __tests__/loanPipeline.test.js   <- Jest tests (never deployed)
```

Template syntax used in `loanPipeline.html`:

| Syntax | Meaning |
|---|---|
| `{tile.total}` | Bind a JS property into the HTML |
| `<template for:each={summary} for:item="tile">` + `key={tile.status}` | Loop (a unique `key` is required) |
| `<template lwc:if={hasRows}>` / `lwc:else` | Conditional rendering |
| `onchange={handleStatusChange}` | Event handler |
| `<lightning-datatable>`, `<lightning-combobox>`, `<lightning-card>` | **Base components** provided by Salesforce |
| `class="slds-..."` | **SLDS** (Salesforce Lightning Design System) CSS classes |

## 6.2 Decorators and reactivity

| Decorator | Purpose |
|---|---|
| `@api` | Public property or method that a parent component can set or call |
| `@wire` | Declaratively get data (Apex or Lightning Data Service). Re-runs when reactive params change |
| `@track` | Only needed to observe *mutations inside* objects or arrays. All fields are reactive when reassigned |

## 6.3 Calling Apex: wire vs imperative

```js
// WIRE: read-only, cached, automatic. The Apex method must be @AuraEnabled(cacheable=true)
@wire(getApplications, { status: '$selectedStatus' })   // '$' = reactive: re-query when it changes
wiredApplications(result) { this.wiredAppsResult = result; ... }

// IMPERATIVE: you decide when. Required for DML (not cacheable)
await updateStatus({ applicationId: row.Id, newStatus });

// After changing data, refresh the cached wire
await refreshApex(this.wiredAppsResult);
```

`handleRowAction` in `loanPipeline.js` shows the full flow: call Apex -> success toast -> refresh both wires; on error, `reduceError()` turns Salesforce's error shapes into readable text and shows an error toast.

**Lightning Data Service (LDS):** for single-record work, use `lightning-record-form`, `lightning-record-edit-form`, or `getRecord`/`updateRecord` from `lightning/uiRecordApi`. These need no Apex, enforce security automatically and share a cache across components. Use Apex when you need lists, aggregates or custom logic, as in our pipeline.

## 6.4 Component communication

- Parent -> child: set `@api` properties.
- Child -> parent: `this.dispatchEvent(new CustomEvent('selected', { detail: id }))`.
- Unrelated components: **Lightning Message Service** (LMS).

## 6.5 Testing LWC with Jest

`__tests__/loanPipeline.test.js` runs on your PC (`npm run test:unit`):
- `createApexTestWireAdapter` lets the test **emit** fake Apex data into the `@wire`.
- `jest.mock(...updateStatus)` fakes the imperative call so it can succeed or fail.
- Tests check the rendered DOM (`el.shadowRoot.querySelector`) and the events fired (toasts).
- `flushPromises()` waits for re-rendering.

## 6.6 Visualforce (legacy)

Visualforce is the older server-rendered page technology (around 2008). Banks still have many VF pages, and the posting calls it "legacy", so you need to be able to read and maintain it. You won't usually build new UIs with it.

`pages/LoanApplicationCreditMemo.page`:
- `standardController="Loan_Application__c"` gives automatic data loading, security and sharing with no Apex.
- `{!Loan_Application__c.Account__r.Name}` is a merge field (expression syntax).
- `<apex:outputField>` formats values (currency, dates) and respects FLS.
- `renderAs="pdf"` turns the page into a PDF. A common VF use case that still exists in banking (credit memos, letters).
- Open it at `/apex/LoanApplicationCreditMemo?id=<record Id>`.

Custom logic would use `controller="MyApexClass"` or `extensions="MyExtension"`.

---

# Part 7: Salesforce APIs and integration

| API | Use for |
|---|---|
| **REST API** | CRUD + SOQL over HTTPS/JSON. Most integrations |
| **SOAP API** | Older enterprise integrations, strongly typed WSDL |
| **Bulk API 2.0** | Loading or extracting millions of records asynchronously |
| **Composite API** | Several operations in one round trip (fewer API calls) |
| **Pub/Sub API** | gRPC streaming of platform events and CDC to external systems |
| **Metadata / Tooling API** | Deployments, CI/CD and IDE features (the `sf` CLI uses these) |
| **Apex REST** (`@RestResource`) | Build your own custom endpoint in Apex |

## 7.1 Walkthrough: `scripts/api/rest-api-demo.ps1`

1. Gets an **access token** from the CLI. In production, systems authenticate through **OAuth 2.0** with a Connected App (Salesforce's newer equivalent is External Client Apps), often using the JWT bearer flow for server-to-server.
2. `GET /services/data/v62.0/query?q=...` runs SOQL over HTTP.
3. `POST /sobjects/Loan_Application__c` creates a record. **Your trigger and Flow run**, because API saves go through the same order of execution.
4. `GET` returns the record with the risk score already filled in.
5. `PATCH` updates it (HTTP 204 = success).
6. `GET /limits` shows API usage. Orgs have a daily API request limit.
7. Sends an invalid record (amount 0) and shows the trigger's `addError` message coming back as an API error.

## 7.2 Calling out from Apex (outbound)

```apex
HttpRequest req = new HttpRequest();
req.setEndpoint('callout:Credit_Bureau/v1/score');   // Named Credential: no secrets in code
req.setMethod('POST');
req.setBody(JSON.serialize(payload));
HttpResponse res = new Http().send(req);
```

- **Named Credentials** keep the URL and auth out of code. Hard-coded secrets fail any bank security review.
- Callouts can't happen after uncommitted DML in the same transaction. Use Queueable or `@future(callout=true)`.
- Tests must mock callouts with `HttpCalloutMock`.

---

# Part 8: Testing, CI/CD, monitoring and production support

## 8.1 Apex testing rules

- **75% code coverage** across the org is required to deploy to production, and every trigger needs some coverage. Coverage is the minimum; **assertions** are what prove the code works.
- `@IsTest` classes don't count toward code size limits. By default, test data is isolated: tests don't see org data and everything rolls back.
- `@TestSetup` creates data once per class. Each test method gets a fresh copy.
- `Test.startTest()` / `Test.stopTest()` give the code under test a **fresh set of governor limits**, and `stopTest()` runs queued async work and delivers events.
- `System.runAs(user)` tests as a specific user (sharing + permission sets with USER_MODE).
- Use the `Assert` class: `Assert.areEqual`, `Assert.isTrue`, `Assert.fail`.

The test suites in this repo:

| Test | What it proves |
|---|---|
| `LoanRiskServiceTest` (5) | Scoring maths for low, medium and high risk, nulls, cap |
| `LoanApplicationTriggerHandlerTest` (9) | Defaults, each validation rule, bypass, **200-record bulk with 0 SOQL**, events -> 200 audit logs, no event without a status change |
| `LoanApplicationControllerTest` (5) | Filtering, aggregates, approve via controller, friendly validation errors, input allow-list. **All run as a least-privilege user** |
| `loanPipeline.test.js` (8) | Tiles, table, filter re-query, error display, success and error toasts |

Test levels for deploys: `NoTestRun` (sandboxes only), `RunSpecifiedTests`, `RunLocalTests` (all tests except managed-package tests, which is what `setup.ps1` uses), `RunAllTestsInOrg`.

## 8.2 Why the setup deploys with `RunLocalTests`

A Developer Edition org behaves like production: deploying Apex runs the tests, and **if any test fails, nothing deploys** (atomic). That is exactly how a bank's production releases work, so you practise the real thing.

## 8.3 CI/CD

**Continuous Integration:** every push or pull request automatically builds and tests the code.
**Continuous Delivery:** tested code is automatically deployed through the environments.

`.github/workflows/ci.yml`:
1. **lwc-unit-tests** (always): `npm ci` + `npm run test:unit:coverage`.
2. **validate-deployment** (once you set the `SFDX_AUTH_URL` secret): logs in to the org with the CLI and runs `sf project deploy validate ... --test-level RunLocalTests`. That is a **check-only** deploy: it compiles everything and runs all tests **without changing the org**. A validated deploy can later be promoted quickly with `sf project deploy quick --job-id <id>`.

The typical team flow (what you will do with JIRA, GitHub and Confluence):

```
JIRA story BBH-123
  -> git checkout -b feature/BBH-123-risk-rating
  -> code + tests in your dev sandbox
  -> git push -> Pull Request -> CI runs -> peer code review (Senior Engineer)
  -> merge to develop -> auto-deploy to SIT -> QA tests
  -> release branch -> UAT (business sign-off) -> change ticket (CAB approval) -> Production
  -> document the change in Confluence
```

Tools you may hear about: **Salesforce DevOps Center**, **Copado**, **Gearset**, **AutoRABIT**, **Flosum** (Salesforce DevOps platforms), **Salesforce Code Analyzer** (static analysis including PMD rules for Apex), **unlocked packages** (modular deployments).

**Never commit secrets.** `.gitignore` excludes `authurl.txt`. The auth URL lives only in GitHub encrypted secrets, and only for this practice org.

## 8.4 Monitoring performance

- **Debug logs:** Setup > Debug Logs > add a trace flag for your user, or run `sf apex tail log`. Log lines show SOQL count, DML, CPU and heap at the end (`LIMIT_USAGE_FOR_NS`).
- **Developer Console:** Logs tab, *Execution Overview* and *Timeline* show where the time goes.
- **Apex Replay Debugger** (VS Code): step through a captured log line by line.
- **`Limits` class** in code (see 4.6).
- **Query Plan** tool (4.8).
- **Event Monitoring** / Apex execution logs: org-wide performance (often used by bank ops teams).
- **Apex Exception Email** / custom error logging (for example a `Log__c` object or a platform event like `Error_Log__e` published *immediately*, so the log survives a rollback).

## 8.5 Troubleshooting a production issue (a playbook to say out loud)

1. **Gather facts:** user, record Id, time, exact error, steps to reproduce, number of users affected. Check the JIRA or incident ticket.
2. **Reproduce** in a sandbox with similar data (never debug by changing production).
3. **Logs:** set a trace flag for the user, reproduce, read the log: which trigger, Flow or class failed, and how many queries or how much CPU.
4. **Classify:**
   - `System.LimitException: Too many SOQL queries: 101` -> a query in a loop, or recursion
   - `Apex CPU time limit exceeded` -> heavy loops or nested loops; move work to async
   - `UNABLE_TO_LOCK_ROW` -> concurrent updates on the same parent record; reduce lock contention or retry
   - `FIELD_CUSTOM_VALIDATION_EXCEPTION` -> a validation rule or `addError`
   - `INSUFFICIENT_ACCESS` / `QueryException` with USER_MODE -> a permission set or sharing gap
   - Flow error emails -> check the Flow's fault paths
5. **Fix + test** (add a test that reproduces the bug first), then **deploy through the pipeline** (hotfix branch), and document the root cause.

---

# Part 9: Hands-on labs

Do these after `setup.cmd` finishes. Each one adds a skill and a line to your resume. Commit after each lab.

### Lab 1: Explore what you deployed (30 min)
1. Open the **Loan Pipeline** tab. Approve the *North York Auto Repair* application (Submitted). Watch the toast and the tiles.
2. Try to Approve the *Queen West Coffee Co.* application (Draft). Read the red toast: that is your Apex `addError`.
3. App Launcher > **Loan Applications** > open the record you approved > **Related** tab > *Decision Logs* and *History*.
4. Open the Flow in Flow Builder and compare it with the XML.
5. Developer Console > Debug > Open Execute Anonymous, and run:
   ```apex
   System.debug([SELECT Name, Risk_Score__c, Risk_Rating__c FROM Loan_Application__c]);
   ```

### Lab 2: Break bulkification on purpose (45 min)
1. In `LoanApplicationTriggerHandler.validate`, add a query **inside** the loop (for example look up the Account industry per record).
2. Deploy: `sf project deploy start --source-dir force-app --test-level RunLocalTests`.
3. The bulk test fails: `queriesUsed` is no longer 0. With more queries per record it would hit `Too many SOQL queries: 101`.
4. Fix it with the collect -> query once -> map pattern (4.7). Redeploy until green. **This is the most common Salesforce interview topic.**

### Lab 3: Add an industry rule (1 hr)
Requirement: "Agriculture businesses get +5 risk points" (as on Williams' Farms).
1. In the handler, query Account industries in bulk (once), and pass them to `LoanRiskService`.
2. Add a test for an Agriculture account.
3. Update the lecture table and the README.

### Lab 4: A Flow subscriber (45 min)
Build a **platform-event-triggered Flow** on `Loan_Decision__e` that posts a Chatter message or sends an email when a loan over $1M is approved. Retrieve it into the project:
`sf project retrieve start --metadata Flow:Your_Flow_Name`

### Lab 5: Record page LWC (1.5 hr)
Create `lwc/loanRiskBadge` that shows the risk rating as a coloured badge on the Loan Application record page using `@api recordId` + `getRecord` (Lightning Data Service). Add it with Lightning App Builder.

### Lab 6: Turn on full CI (20 min)
Run `.\setup.ps1 -Only 11`, set the secret, make a small change, push, and watch the **Actions** tab run both jobs. Take a screenshot for your portfolio.

### Lab 7: Trailhead badges (parallel, a few hours)
Earn these. They are free, verifiable, and recruiters recognize them:
- Apex Basics & Database
- Apex Triggers
- Apex Testing
- Lightning Web Components Basics
- Flow Builder / Record-Triggered Flows
- Platform Events Basics
- Salesforce DX / Git and GitHub Basics

---

# Part 10: Interview preparation

## 10.1 Explain the project in 60 seconds

> "I built BBHub-lite, a small business-banking credit pipeline on Salesforce, modelled on a CRM-plus-credit platform like BBHub. Loan applications are scored by an Apex trigger. I used the one-trigger-per-object pattern with a handler and a separate risk service, and it's fully bulkified: my bulk test pushes 200 records through and asserts zero SOQL queries. A before-save Flow routes each application to a review tier by amount. When an application is approved or declined, the trigger publishes a platform event after commit, and a subscriber writes an audit log. Loan officers work the queue in a Lightning Web Component with wired and imperative Apex calls. On the security side, the controller uses with sharing, USER_MODE queries and user-mode DML, and the tests run as a least-privilege user with a permission set. There's also a Visualforce PDF credit memo and a REST API script. Everything deploys through GitHub Actions with Jest tests and a check-only deployment that runs all the Apex tests."

## 10.2 Likely questions with model answers

**1. What are governor limits and why do they exist?**
Per-transaction caps (100 SOQL, 150 DML, 50,000 rows, 10 s CPU, 6 MB heap for synchronous code) that protect the shared multi-tenant platform. They can't be caught, so code must be designed around them: bulkify, query once, use maps, move heavy work to async.

**2. What does "bulkify" mean? Show me.**
Handle collections, not single records. Never SOQL or DML inside loops. Collect Ids, query once into a Map, loop and look up, and do one DML at the end. (Draw the 4.7 example.)

**3. Before vs after trigger?**
Before: change fields on the same record without DML, and validate. After: the record has an Id; work with related records and publish events. `Trigger.new` is read-only in after.

**4. Why one trigger per object and a handler?**
Several triggers on one object have no guaranteed order. A handler makes logic testable and reusable, and allows bypass switches and recursion control.

**5. How do you stop trigger recursion?**
Static Boolean or `Set<Id>` of processed records in a handler class (statics last for the transaction), and only act on real field changes by comparing with `Trigger.oldMap`.

**6. Flow or Apex: when do you choose which?**
Flow for straightforward record automation, screens and notifications that admins or BAs maintain. Apex for complex logic, high volume, integrations or careful error handling. Prefer before-save Flows for same-record updates. Don't let both update the same field.

**7. What is a platform event and when would you use it?**
A message on Salesforce's event bus for decoupled, event-driven integration: notifying a core banking system or document service when a loan is decided. Publish-after-commit ensures you never announce something that rolled back. Subscribers can be Apex triggers, Flows, LWC (empApi) or external systems through the Pub/Sub API, with replay for 72 hours.

**8. with sharing vs without sharing vs inherited sharing?**
Record-level visibility for the running user, all records (system), or the caller's mode. Sharing keywords don't enforce CRUD/FLS. Use `WITH USER_MODE` / `as user` or `stripInaccessible` for that.

**9. How do you protect customer financial data in Apex and LWC?**
Least-privilege permission sets, `with sharing`, USER_MODE queries and DML, allow-listed inputs, bind variables (no SOQL injection), no sensitive data in debug logs, generic error messages, Named Credentials for secrets, field history and audit logs, and platform encryption where required.

**10. Wire vs imperative Apex in LWC?**
Wire: declarative, reactive, cached, read-only (`cacheable=true`). Imperative: called when you choose, needed for DML, returns a Promise. After DML, call `refreshApex` on the wired result.

**11. What happens when you save a record? (Order of execution)**
System validation -> before-save Flows -> before triggers -> validation rules -> duplicate rules -> save -> after triggers -> assignment/workflow/escalation -> after-save Flows -> roll-ups -> commit -> post-commit (emails, async jobs, publish-after-commit events).

**12. How do you make a SOQL query efficient?**
Filter on indexed fields (selective), avoid leading wildcards and negative operators, select only the fields you need, use LIMIT, use aggregates, check the Query Plan, and never query inside loops.

**13. What's the deployment test requirement?**
75% org-wide coverage and coverage on every trigger, with tests passing; `RunLocalTests` is typical. A check-only validate can be quick-deployed later.

**14. Describe your CI/CD pipeline.**
Feature branch -> PR -> GitHub Actions runs Jest, then a check-only deploy with all Apex tests against an org authenticated with an encrypted secret -> code review -> merge -> promote through SIT/UAT -> production behind change approval.

**15. A user reports "Too many SOQL queries: 101". What do you do?**
Get the record and time, set a trace flag, reproduce in a sandbox, read the log to find the query running per record or the recursion, bulkify or add a recursion guard, add a 200-record regression test, and deploy through the pipeline.

**16. What is Visualforce and why is it legacy?**
Server-rendered pages with a controller model (standard or custom controller/extension). LWC replaced it for modern UI, but it is still used for PDFs (`renderAs="pdf"`), email templates and existing pages that need maintenance.

**17. Lookup vs Master-Detail?**
Lookup is loose (optional parent, own sharing). Master-Detail is tight (cascade delete, inherited sharing, roll-up summaries).

**18. What async options exist?**
`@future`, Queueable (chainable, sObject params), Batch (large volumes, chunked), Schedulable, platform-event triggers.

**19. What is nCino?**
A commercial lending (loan origination) platform built natively on Salesforce and installed as a managed package with its own namespace. Engineers extend it with Apex, Flows and LWCs, and integrate it with bank systems, without modifying the package's own code.

**20. Where have you used AI or GitHub Copilot?** (posting: "a plus")
Be honest: describe using AI assistants to generate boilerplate and tests and to explain errors, then reviewing and verifying everything yourself, for example by running the tests and reading the logs.

## 10.3 Behavioural answers from your own background

- *Accuracy and controls:* Loblaws cash office. Balancing tills, investigating overages and shortages, and logging totals is the same mindset as audit trails and validation rules.
- *Customer orientation:* Jamaica Postal Service and Loblaws front end.
- *Business understanding of lending:* running Williams' Farms. You understand from experience why revenue, debt and time in business matter to a lender.
- *Fast learner:* Centennial diploma, plus several self-built full-stack projects (LendFlow, CreditLens, VendorIQ) and now this Salesforce stack.

## 10.4 Resume bullets (use once the project is deployed and on GitHub)

- Built **BBHub-lite**, a Salesforce business-banking credit pipeline: custom data model, **Apex** trigger framework (handler + service), **record-triggered Flow**, **Platform Events** pub/sub and an audit log, a **Lightning Web Component** work queue, a **Visualforce** PDF credit memo and a **REST API** integration script.
- Wrote bulk-safe Apex that respects **governor limits**, proven by a 200-record test asserting zero SOQL in the trigger path; used aggregate SOQL for pipeline metrics.
- Enforced banking-grade security with `with sharing`, **USER_MODE** SOQL/DML, a least-privilege permission set, field history tracking, and tests that run as a restricted user.
- Set up **CI/CD** with GitHub Actions (Jest LWC tests + check-only Salesforce deployment running all Apex tests) using the Salesforce CLI (sf).

---

# Part 11: Cheat sheet and glossary

## 11.1 Apex snippets

```apex
// Query into a map
Map<Id, Account> m = new Map<Id, Account>([SELECT Id, Name FROM Account WHERE Id IN :ids]);

// Detect a field change in a trigger
if (rec.Status__c != Trigger.oldMap.get(rec.Id).Status__c) { ... }

// Record-level error
rec.addError(Loan_Application__c.Status__c, 'Message');

// Publish events
EventBus.publish(eventsList);

// Secure query and DML
List<X__c> rows = [SELECT Id FROM X__c WITH USER_MODE];
update as user rows;

// Limits
Limits.getQueries(); Limits.getDmlStatements(); Limits.getCpuTime(); Limits.getHeapSize();

// Queueable
public class MyJob implements Queueable { public void execute(QueueableContext ctx) { ... } }
System.enqueueJob(new MyJob());
```

## 11.2 Glossary

| Term | Meaning |
|---|---|
| **Org** | One Salesforce instance |
| **sObject** | Any Salesforce object type (Account, `Loan_Application__c`) |
| **SOQL / SOSL** | Query language / full-text search language |
| **DML** | insert, update, delete, upsert, undelete |
| **Governor limits** | Per-transaction resource caps |
| **Bulkification** | Writing code that handles 200+ records efficiently |
| **CRUD / FLS** | Object permissions / field-level security |
| **OWD** | Org-wide default sharing level |
| **Permission set** | Add-on bundle of permissions assigned to users |
| **Managed package** | Installed app with its own namespace (for example nCino) |
| **Namespace** | Prefix that isolates a package's components (`LLC_BI__`) |
| **Platform Event** | Custom message on the event bus (`__e`) |
| **CDC** | Change Data Capture: automatic change events |
| **LWC / LDS / SLDS** | Lightning Web Components / Lightning Data Service / Lightning Design System |
| **Wire** | Declarative reactive data binding in LWC |
| **Named Credential** | Secure storage of callout endpoints and auth |
| **Sandbox** | Copy of production for dev and testing |
| **Check-only deploy** | Validates and runs tests without changing the org |
| **API version** | Release-specific behaviour contract for a component (62.0 here) |
| **Automated Process user** | System user that runs platform event triggers |

---

*Next step after finishing: complete Labs 2 and 3, earn at least three Trailhead badges, push to GitHub, and add the badges and the repo link to your resume and LinkedIn.*
