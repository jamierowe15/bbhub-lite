// ---------------------------------------------------------------------------
// BBHub-lite demo data (Anonymous Apex). Safe to run again: it deletes the
// previous demo data first.
//   sf apex run --file scripts/apex/seed.apex --target-org bbhub
// All businesses are fictional.
// ---------------------------------------------------------------------------
delete [SELECT Id FROM Loan_Decision_Log__c WHERE Loan_Application__r.Account__r.Name LIKE 'BBHub Demo%'];
delete [SELECT Id FROM Loan_Application__c WHERE Account__r.Name LIKE 'BBHub Demo%'];
delete [SELECT Id FROM Account WHERE Name LIKE 'BBHub Demo%'];

List<Account> accounts = new List<Account>{
    new Account(Name = 'BBHub Demo - Maple Leaf Bakery', Industry = 'Food & Beverage'),
    new Account(Name = 'BBHub Demo - North York Auto Repair', Industry = 'Retail'),
    new Account(Name = 'BBHub Demo - Lakeshore Logistics', Industry = 'Transportation'),
    new Account(Name = 'BBHub Demo - Kingston Dental Group', Industry = 'Healthcare'),
    new Account(Name = 'BBHub Demo - Blue Mountain Farms', Industry = 'Agriculture'),
    new Account(Name = 'BBHub Demo - Queen West Coffee Co.', Industry = 'Food & Beverage')
};
insert accounts;

// Status starts as Draft or Submitted. Decisions happen afterwards, through the trigger rules.
List<Loan_Application__c> apps = new List<Loan_Application__c>{
    //                                        Account          Amount      Revenue     Debt      Yrs  Credit  Status
    new Loan_Application__c(Account__c = accounts[0].Id, Requested_Amount__c = 150000,  Annual_Revenue__c = 1200000, Existing_Debt__c = 50000,  Years_In_Business__c = 12, Credit_Score__c = 810, Status__c = 'Submitted'),
    new Loan_Application__c(Account__c = accounts[1].Id, Requested_Amount__c = 80000,   Annual_Revenue__c = 400000,  Existing_Debt__c = 120000, Years_In_Business__c = 4,  Credit_Score__c = 690, Status__c = 'Submitted'),
    new Loan_Application__c(Account__c = accounts[2].Id, Requested_Amount__c = 1750000, Annual_Revenue__c = 6000000, Existing_Debt__c = 900000, Years_In_Business__c = 15, Credit_Score__c = 760, Status__c = 'Submitted'),
    new Loan_Application__c(Account__c = accounts[3].Id, Requested_Amount__c = 400000,  Annual_Revenue__c = 2500000, Existing_Debt__c = 300000, Years_In_Business__c = 8,  Credit_Score__c = 740, Status__c = 'Submitted'),
    new Loan_Application__c(Account__c = accounts[4].Id, Requested_Amount__c = 250000,  Annual_Revenue__c = 180000,  Existing_Debt__c = 60000,  Years_In_Business__c = 1,  Credit_Score__c = 580, Status__c = 'Submitted'),
    new Loan_Application__c(Account__c = accounts[5].Id, Requested_Amount__c = 60000,   Annual_Revenue__c = 350000,  Existing_Debt__c = 20000,  Years_In_Business__c = 3,  Credit_Score__c = 655, Status__c = 'Draft'),
    new Loan_Application__c(Account__c = accounts[0].Id, Requested_Amount__c = 500000,  Annual_Revenue__c = 1200000, Existing_Debt__c = 200000, Years_In_Business__c = 12, Credit_Score__c = 810, Status__c = 'Submitted')
};
insert apps;

// Move a few through the process so every stage has data.
apps[0].Status__c = 'Approved';       // strong bakery: approved
apps[3].Status__c = 'Credit Review';  // dental group: with an analyst
apps[4].Status__c = 'Declined';       // 1-year farm, high leverage: declined
update new List<Loan_Application__c>{ apps[0], apps[3], apps[4] };

System.debug('BBHub-lite seed complete: ' + accounts.size() + ' accounts, ' + apps.size() + ' loan applications.');
