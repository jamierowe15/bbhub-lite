/**
 * Tests the LWC controller as a least-privilege loan officer (Standard User
 * + BBHub_Lite_User permission set), so USER_MODE security is exercised.
 */
@IsTest
private class LoanApplicationControllerTest {

    @TestSetup
    static void setup() {
        TestDataFactory.createLoanOfficer();
        Account acc = TestDataFactory.createAccount('Controller Test Co.');
        List<Loan_Application__c> apps = new List<Loan_Application__c>();
        apps.addAll(TestDataFactory.buildApplications(acc.Id, 3, 'Submitted'));
        apps.addAll(TestDataFactory.buildApplications(acc.Id, 2, 'Draft'));
        insert apps;
    }

    private static User officer() {
        return [SELECT Id FROM User WHERE LastName = 'Officer' AND Alias = 'lofficer' ORDER BY CreatedDate DESC LIMIT 1];
    }

    @IsTest
    static void getApplicationsFiltersByStatus() {
        System.runAs(officer()) {
            Assert.areEqual(5, LoanApplicationController.getApplications('All').size());
            Assert.areEqual(5, LoanApplicationController.getApplications(null).size());
            Assert.areEqual(3, LoanApplicationController.getApplications('Submitted').size());
            Assert.areEqual(0, LoanApplicationController.getApplications('Approved').size());
        }
    }

    @IsTest
    static void pipelineSummaryGroupsByStatus() {
        System.runAs(officer()) {
            Map<String, LoanApplicationController.StatusSummary> byStatus = new Map<String, LoanApplicationController.StatusSummary>();
            for (LoanApplicationController.StatusSummary s : LoanApplicationController.getPipelineSummary()) {
                byStatus.put(s.status, s);
            }
            Assert.areEqual(3, byStatus.get('Submitted').total);
            Assert.areEqual(2, byStatus.get('Draft').total);
            Assert.isTrue(byStatus.get('Submitted').amount > 0);
        }
    }

    @IsTest
    static void updateStatusApproves() {
        Loan_Application__c app = [SELECT Id FROM Loan_Application__c WHERE Status__c = 'Submitted' LIMIT 1];
        System.runAs(officer()) {
            Test.startTest();
            LoanApplicationController.updateStatus(app.Id, 'Approved');
            Test.stopTest();
        }
        Assert.areEqual('Approved', [SELECT Status__c FROM Loan_Application__c WHERE Id = :app.Id].Status__c);
        Assert.areEqual(1, [SELECT COUNT() FROM Loan_Decision_Log__c WHERE Loan_Application__c = :app.Id]);
    }

    @IsTest
    static void updateStatusSurfacesValidationError() {
        Loan_Application__c draft = [SELECT Id FROM Loan_Application__c WHERE Status__c = 'Draft' LIMIT 1];
        System.runAs(officer()) {
            try {
                LoanApplicationController.updateStatus(draft.Id, 'Approved');
                Assert.fail('Expected an AuraHandledException');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('Only Submitted or Credit Review'), e.getMessage());
            }
        }
    }

    @IsTest
    static void updateStatusRejectsUnknownStatus() {
        Loan_Application__c app = [SELECT Id FROM Loan_Application__c LIMIT 1];
        System.runAs(officer()) {
            try {
                LoanApplicationController.updateStatus(app.Id, 'Paid Out');
                Assert.fail('Expected an AuraHandledException');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('Unsupported status'));
            }
        }
    }
}
