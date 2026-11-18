/**
 * LoanDecisionEventHandler
 * ----------------------------------------------------------------------------
 * Subscriber for the Loan_Decision__e platform event. Writes an audit record
 * (Loan_Decision_Log__c) for every decision.
 *
 * Platform event triggers:
 *  - only support "after insert"
 *  - run asynchronously, as the Automated Process system user
 *  - receive events in batches (up to 2,000), so this code is bulkified
 *
 * "without sharing" is intentional: an audit log must always be written,
 * whatever the sharing settings. Users get read-only access to the log via the
 * BBHub_Lite_User permission set.
 */
public without sharing class LoanDecisionEventHandler {

    public static void handle(List<Loan_Decision__e> events) {
        List<Loan_Decision_Log__c> logs = new List<Loan_Decision_Log__c>();
        for (Loan_Decision__e evt : events) {
            if (String.isBlank(evt.Loan_Application_Id__c)) {
                continue;
            }
            logs.add(
                new Loan_Decision_Log__c(
                    Loan_Application__c = Id.valueOf(evt.Loan_Application_Id__c),
                    Decision__c = evt.Decision__c,
                    Requested_Amount__c = evt.Requested_Amount__c,
                    Logged_At__c = System.now()
                )
            );
        }
        if (!logs.isEmpty()) {
            insert logs; // one DML for the whole batch
        }
    }
}
