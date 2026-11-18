/**
 * Integration tests for LoanApplicationTrigger + handler + platform event
 * subscriber. Includes a 200-record bulk test, the standard way to prove a
 * trigger is bulkified and stays within governor limits.
 */
@IsTest
private class LoanApplicationTriggerHandlerTest {

    @TestSetup
    static void setup() {
        TestDataFactory.createAccount('Test Bakery Inc.');
    }

    private static Id accountId() {
        return [SELECT Id FROM Account WHERE Name = 'Test Bakery Inc.' LIMIT 1].Id;
    }

    @IsTest
    static void insertDefaultsStatusAndScoresRisk() {
        Loan_Application__c app = TestDataFactory.buildApplications(accountId(), 1, null)[0];
        app.Credit_Score__c = 550;
        Test.startTest();
        insert app;
        Test.stopTest();

        Loan_Application__c saved = [SELECT Status__c, Risk_Score__c, Risk_Rating__c FROM Loan_Application__c WHERE Id = :app.Id];
        Assert.areEqual('Draft', saved.Status__c, 'Blank status should default to Draft');
        Assert.areEqual(40, saved.Risk_Score__c);
        Assert.areEqual('Medium', saved.Risk_Rating__c);
    }

    @IsTest
    static void rejectsZeroAmount() {
        Loan_Application__c app = TestDataFactory.buildApplications(accountId(), 1, 'Draft')[0];
        app.Requested_Amount__c = 0;
        Database.SaveResult result = Database.insert(app, false);
        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains('greater than zero'));
    }

    @IsTest
    static void requiresAccountOutsideDraft() {
        Loan_Application__c app = TestDataFactory.buildApplications(null, 1, 'Submitted')[0];
        Database.SaveResult result = Database.insert(app, false);
        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains('Account'));
    }

    @IsTest
    static void cannotCreateAsApproved() {
        Loan_Application__c app = TestDataFactory.buildApplications(accountId(), 1, 'Approved')[0];
        Database.SaveResult result = Database.insert(app, false);
        Assert.isFalse(result.isSuccess());
    }

    @IsTest
    static void cannotApproveFromDraft() {
        Loan_Application__c app = TestDataFactory.buildApplications(accountId(), 1, 'Draft')[0];
        insert app;
        app.Status__c = 'Approved';
        Database.SaveResult result = Database.update(app, false);
        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains('Only Submitted or Credit Review'));
    }

    @IsTest
    static void cannotChangeDecidedApplication() {
        Loan_Application__c app = TestDataFactory.buildApplications(accountId(), 1, 'Submitted')[0];
        insert app;
        app.Status__c = 'Declined';
        update app;

        app.Status__c = 'Credit Review';
        Database.SaveResult result = Database.update(app, false);
        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains('cannot change status'));
    }

    @IsTest
    static void bypassSkipsAllLogic() {
        LoanApplicationTriggerHandler.bypass = true;
        Loan_Application__c app = TestDataFactory.buildApplications(accountId(), 1, 'Draft')[0];
        insert app;
        Loan_Application__c saved = [SELECT Risk_Score__c FROM Loan_Application__c WHERE Id = :app.Id];
        Assert.isNull(saved.Risk_Score__c, 'Handler should not run while bypassed');
    }

    /**
     * Bulk test: 200 records is the size of one trigger batch. The trigger
     * handler itself issues no SOQL, and the platform event subscriber writes
     * all 200 audit logs with one DML statement.
     */
    @IsTest
    static void bulkApprovalPublishesEventsAndWritesLogs() {
        List<Loan_Application__c> apps = TestDataFactory.buildApplications(accountId(), 200, 'Submitted');
        insert apps;
        for (Loan_Application__c app : apps) {
            app.Status__c = 'Approved';
        }

        Test.startTest();
        Integer queriesBefore = Limits.getQueries();
        update apps;
        Integer queriesUsed = Limits.getQueries() - queriesBefore;
        Test.stopTest(); // delivers the published platform events to the subscriber trigger

        Assert.areEqual(0, queriesUsed, 'The trigger handler should not issue SOQL');
        Assert.areEqual(200, [SELECT COUNT() FROM Loan_Application__c WHERE Decision_Date__c != null]);
        Assert.areEqual(200, [SELECT COUNT() FROM Loan_Decision_Log__c WHERE Decision__c = 'Approved']);
    }

    @IsTest
    static void noEventWhenStatusDoesNotChange() {
        Loan_Application__c app = TestDataFactory.buildApplications(accountId(), 1, 'Submitted')[0];
        insert app;
        Test.startTest();
        app.Requested_Amount__c = 150000; // edit, but no decision
        update app;
        Test.stopTest();
        Assert.areEqual(0, [SELECT COUNT() FROM Loan_Decision_Log__c]);
    }
}
