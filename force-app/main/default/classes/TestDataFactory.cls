/**
 * TestDataFactory
 * ----------------------------------------------------------------------------
 * Builds test records in one place so every test class creates data the same
 * way. Marked @IsTest: it does not count toward your org's Apex size limit and
 * cannot be called from production code.
 */
@IsTest
public class TestDataFactory {

    public static final String PERMISSION_SET = 'BBHub_Lite_User';

    public static Account createAccount(String name) {
        Account acc = new Account(Name = name);
        insert acc;
        return acc;
    }

    /** Builds (does not insert) applications with healthy financials. */
    public static List<Loan_Application__c> buildApplications(Id accountId, Integer count, String status) {
        List<Loan_Application__c> apps = new List<Loan_Application__c>();
        for (Integer i = 0; i < count; i++) {
            apps.add(
                new Loan_Application__c(
                    Account__c = accountId,
                    Status__c = status,
                    Requested_Amount__c = 100000 + i,
                    Annual_Revenue__c = 2000000,
                    Existing_Debt__c = 100000,
                    Years_In_Business__c = 10,
                    Credit_Score__c = 800
                )
            );
        }
        return apps;
    }

    /**
     * Creates a Standard User with the BBHub_Lite_User permission set, to test
     * the app the way a real loan officer would use it (least privilege).
     * Setup objects (User, PermissionSetAssignment) are inserted inside
     * System.runAs to avoid MIXED_DML_OPERATION errors.
     */
    public static User createLoanOfficer() {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String unique = String.valueOf(Datetime.now().getTime()) + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User officer = new User(
            Alias = 'lofficer',
            Email = 'loan.officer@example.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Loan',
            LastName = 'Officer',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_CA',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Toronto',
            Username = 'loan.officer.' + unique + '@bbhub-lite.example.com'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert officer;
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = :PERMISSION_SET LIMIT 1];
            insert new PermissionSetAssignment(AssigneeId = officer.Id, PermissionSetId = ps.Id);
        }
        return officer;
    }
}
