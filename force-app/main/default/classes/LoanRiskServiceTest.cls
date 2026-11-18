/**
 * Pure unit tests: no DML, no SOQL. Records are built in memory only.
 */
@IsTest
private class LoanRiskServiceTest {

    @IsTest
    static void strongBusinessIsLowRisk() {
        Loan_Application__c app = new Loan_Application__c(
            Credit_Score__c = 800,
            Annual_Revenue__c = 2000000,
            Existing_Debt__c = 100000,
            Requested_Amount__c = 200000,
            Years_In_Business__c = 10
        );
        Decimal score = LoanRiskService.calculateRiskScore(app);
        Assert.areEqual(0, score, 'Leverage 0.15, credit 800 and 10 years should add no risk points');
        Assert.areEqual('Low', LoanRiskService.ratingFor(score));
    }

    @IsTest
    static void mediumRiskBusiness() {
        Loan_Application__c app = new Loan_Application__c(
            Credit_Score__c = 700, // +10
            Annual_Revenue__c = 500000,
            Existing_Debt__c = 100000,
            Requested_Amount__c = 200000, // leverage 0.6 -> +15
            Years_In_Business__c = 3 // +10
        );
        Decimal score = LoanRiskService.calculateRiskScore(app);
        Assert.areEqual(35, score);
        Assert.areEqual('Medium', LoanRiskService.ratingFor(score));
    }

    @IsTest
    static void weakBusinessIsHighRisk() {
        Loan_Application__c app = new Loan_Application__c(
            Credit_Score__c = 550, // +40
            Annual_Revenue__c = 100000,
            Existing_Debt__c = 80000,
            Requested_Amount__c = 50000, // leverage 1.3 -> +30
            Years_In_Business__c = 1 // +20
        );
        Decimal score = LoanRiskService.calculateRiskScore(app);
        Assert.areEqual(90, score);
        Assert.areEqual('High', LoanRiskService.ratingFor(score));
    }

    @IsTest
    static void missingDataIsTreatedAsRiskyAndCapped() {
        Loan_Application__c app = new Loan_Application__c(); // every input null
        Decimal score = LoanRiskService.calculateRiskScore(app);
        // credit 0 (+40) + no revenue (+30) + 0 years (+20) = 90
        Assert.areEqual(90, score);
        Assert.isTrue(score <= LoanRiskService.MAX_SCORE);
    }

    @IsTest
    static void applyRiskWritesBothFields() {
        List<Loan_Application__c> apps = new List<Loan_Application__c>{
            new Loan_Application__c(Credit_Score__c = 650, Annual_Revenue__c = 1000000, Existing_Debt__c = 0,
                                    Requested_Amount__c = 300000, Years_In_Business__c = 6)
        };
        LoanRiskService.applyRisk(apps);
        // credit 650 (+25) + leverage 0.3 (+5) + 6 years (0) = 30 -> Low
        Assert.areEqual(30, apps[0].Risk_Score__c);
        Assert.areEqual('Low', apps[0].Risk_Rating__c);
        Assert.isNull(LoanRiskService.ratingFor(null));
    }
}
