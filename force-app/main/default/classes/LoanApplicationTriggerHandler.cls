/**
 * LoanApplicationTriggerHandler
 * ----------------------------------------------------------------------------
 * All logic for LoanApplicationTrigger lives here ("one trigger per object,
 * logic in a handler class"). The trigger itself is one line.
 *
 * Bulkification rules followed in this class:
 *  - Every method takes a List / Map, never a single record.
 *  - ZERO SOQL queries and ZERO DML statements inside loops.
 *  - Platform events are collected into one list and published once.
 *
 * Context summary
 *  BEFORE INSERT : default status, score risk, validate
 *  BEFORE UPDATE : score risk, validate status transitions, stamp decision date
 *  AFTER UPDATE  : publish Loan_Decision__e for newly decided applications
 *
 * (Before-save changes are made directly on Trigger.new, so they need no DML.)
 */
public with sharing class LoanApplicationTriggerHandler {

    /** Lets data loads or tests switch the handler off: LoanApplicationTriggerHandler.bypass = true; */
    public static Boolean bypass = false;

    public static final String STATUS_DRAFT = 'Draft';
    public static final String STATUS_SUBMITTED = 'Submitted';
    public static final String STATUS_CREDIT_REVIEW = 'Credit Review';
    public static final String STATUS_APPROVED = 'Approved';
    public static final String STATUS_DECLINED = 'Declined';

    public static final Set<String> DECISION_STATUSES = new Set<String>{ STATUS_APPROVED, STATUS_DECLINED };
    public static final Set<String> DECIDABLE_FROM = new Set<String>{ STATUS_SUBMITTED, STATUS_CREDIT_REVIEW };

    public static void handle(
        System.TriggerOperation operation,
        List<Loan_Application__c> newList,
        Map<Id, Loan_Application__c> oldMap
    ) {
        if (bypass) {
            return;
        }
        switch on operation {
            when BEFORE_INSERT {
                setDefaults(newList);
                LoanRiskService.applyRisk(newList);
                validate(newList, null);
            }
            when BEFORE_UPDATE {
                LoanRiskService.applyRisk(newList);
                validate(newList, oldMap);
                stampDecisionDate(newList, oldMap);
            }
            when AFTER_UPDATE {
                publishDecisionEvents(newList, oldMap);
            }
        }
    }

    // ---------------------------------------------------------------- before

    private static void setDefaults(List<Loan_Application__c> newList) {
        for (Loan_Application__c app : newList) {
            if (String.isBlank(app.Status__c)) {
                app.Status__c = STATUS_DRAFT;
            }
        }
    }

    /**
     * Business rules. addError() blocks the save for that one record only and
     * shows the message on the field in the UI, without throwing an exception
     * that would fail the whole batch.
     */
    private static void validate(List<Loan_Application__c> newList, Map<Id, Loan_Application__c> oldMap) {
        for (Loan_Application__c app : newList) {
            if (app.Requested_Amount__c == null || app.Requested_Amount__c <= 0) {
                app.addError(Loan_Application__c.Requested_Amount__c, 'Requested Amount must be greater than zero.');
            }

            if (app.Status__c != STATUS_DRAFT && app.Account__c == null) {
                app.addError(Loan_Application__c.Account__c, 'A business (Account) is required before the application leaves Draft.');
            }

            Boolean isNewDecision = DECISION_STATUSES.contains(app.Status__c);
            if (oldMap == null) {
                if (isNewDecision) {
                    app.addError(Loan_Application__c.Status__c, 'A new application cannot be created as ' + app.Status__c + '.');
                }
                continue;
            }

            Loan_Application__c oldApp = oldMap.get(app.Id);
            Boolean statusChanged = app.Status__c != oldApp.Status__c;

            if (statusChanged && isNewDecision && !DECIDABLE_FROM.contains(oldApp.Status__c)) {
                app.addError(
                    Loan_Application__c.Status__c,
                    'Only Submitted or Credit Review applications can be ' + app.Status__c + '.'
                );
            }
            if (statusChanged && DECISION_STATUSES.contains(oldApp.Status__c)) {
                app.addError(Loan_Application__c.Status__c, 'A decided application cannot change status.');
            }
        }
    }

    private static void stampDecisionDate(List<Loan_Application__c> newList, Map<Id, Loan_Application__c> oldMap) {
        for (Loan_Application__c app : newList) {
            Loan_Application__c oldApp = oldMap.get(app.Id);
            if (app.Status__c != oldApp.Status__c && DECISION_STATUSES.contains(app.Status__c)) {
                app.Decision_Date__c = System.now();
            }
        }
    }

    // ----------------------------------------------------------------- after

    /**
     * Publishes one Loan_Decision__e per newly decided application.
     * Publish behaviour is "Publish After Commit": if the transaction rolls
     * back, no event is sent, so subscribers never hear about a decision
     * that did not actually save.
     */
    private static void publishDecisionEvents(List<Loan_Application__c> newList, Map<Id, Loan_Application__c> oldMap) {
        List<Loan_Decision__e> events = new List<Loan_Decision__e>();
        for (Loan_Application__c app : newList) {
            Loan_Application__c oldApp = oldMap.get(app.Id);
            if (app.Status__c != oldApp.Status__c && DECISION_STATUSES.contains(app.Status__c)) {
                events.add(
                    new Loan_Decision__e(
                        Loan_Application_Id__c = app.Id,
                        Decision__c = app.Status__c,
                        Requested_Amount__c = app.Requested_Amount__c
                    )
                );
            }
        }
        if (events.isEmpty()) {
            return;
        }
        List<Database.SaveResult> results = EventBus.publish(events); // one call for the whole batch
        for (Database.SaveResult result : results) {
            if (!result.isSuccess()) {
                for (Database.Error err : result.getErrors()) {
                    System.debug(LoggingLevel.ERROR, 'Loan_Decision__e publish failed: ' + err.getStatusCode() + ' - ' + err.getMessage());
                }
            }
        }
    }
}
