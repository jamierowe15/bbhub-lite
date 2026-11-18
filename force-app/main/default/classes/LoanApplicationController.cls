/**
 * LoanApplicationController
 * ----------------------------------------------------------------------------
 * Apex methods called by the loanPipeline Lightning Web Component.
 *
 * Security (important in banking):
 *  - "with sharing": the user only sees records their sharing rules allow.
 *  - "WITH USER_MODE" (SOQL) and "as user" (DML): object- and field-level
 *    security (CRUD/FLS) are enforced for the running user. If the user lacks
 *    access to a field, the query fails instead of leaking data.
 *  - Inputs are validated against an allow-list before any DML.
 *  - Errors are returned as AuraHandledException with a safe message.
 */
public with sharing class LoanApplicationController {

    private static final Integer MAX_ROWS = 200;
    private static final Set<String> ALLOWED_TARGET_STATUSES = new Set<String>{
        LoanApplicationTriggerHandler.STATUS_SUBMITTED,
        LoanApplicationTriggerHandler.STATUS_CREDIT_REVIEW,
        LoanApplicationTriggerHandler.STATUS_APPROVED,
        LoanApplicationTriggerHandler.STATUS_DECLINED
    };

    /** cacheable=true: read-only, results cached on the client, can be used with @wire. */
    @AuraEnabled(cacheable=true)
    public static List<Loan_Application__c> getApplications(String status) {
        if (String.isBlank(status) || status == 'All') {
            return [
                SELECT Id, Name, Account__c, Account__r.Name, Requested_Amount__c, Status__c,
                       Risk_Score__c, Risk_Rating__c, Review_Tier__c, Decision_Date__c, CreatedDate
                FROM Loan_Application__c
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT :MAX_ROWS
            ];
        }
        return [
            SELECT Id, Name, Account__c, Account__r.Name, Requested_Amount__c, Status__c,
                   Risk_Score__c, Risk_Rating__c, Review_Tier__c, Decision_Date__c, CreatedDate
            FROM Loan_Application__c
            WHERE Status__c = :status
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT :MAX_ROWS
        ];
    }

    /** One aggregate query instead of loading every record and counting in Apex. */
    @AuraEnabled(cacheable=true)
    public static List<StatusSummary> getPipelineSummary() {
        List<StatusSummary> summaries = new List<StatusSummary>();
        for (AggregateResult row : [
            SELECT Status__c stage, COUNT(Id) cnt, SUM(Requested_Amount__c) amt
            FROM Loan_Application__c
            WITH USER_MODE
            GROUP BY Status__c
        ]) {
            summaries.add(
                new StatusSummary((String) row.get('stage'), (Integer) row.get('cnt'), (Decimal) row.get('amt'))
            );
        }
        return summaries;
    }

    /** Called imperatively from the LWC (not cacheable because it changes data). */
    @AuraEnabled
    public static void updateStatus(Id applicationId, String newStatus) {
        if (applicationId == null || !ALLOWED_TARGET_STATUSES.contains(newStatus)) {
            throw buildError('Unsupported status change: ' + newStatus);
        }
        Loan_Application__c app = new Loan_Application__c(Id = applicationId, Status__c = newStatus);
        try {
            update as user app;
        } catch (DmlException e) {
            throw buildError(e.getDmlMessage(0));
        } catch (System.SecurityException e) {
            throw buildError('You do not have permission to update this application.');
        }
    }

    private static AuraHandledException buildError(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message); // so getMessage() returns it in Apex tests too
        return ex;
    }

    /** Wrapper returned to the LWC. Only @AuraEnabled properties are serialized. */
    public class StatusSummary {
        @AuraEnabled
        public String status;
        @AuraEnabled
        public Integer total;
        @AuraEnabled
        public Decimal amount;

        public StatusSummary(String status, Integer total, Decimal amount) {
            this.status = status;
            this.total = total;
            this.amount = amount == null ? 0 : amount;
        }
    }
}
