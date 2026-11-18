/**
 * One trigger per object. No logic here: everything is delegated to the
 * handler so it is testable, readable and runs in a predictable order.
 */
trigger LoanApplicationTrigger on Loan_Application__c (before insert, before update, after update) {
    LoanApplicationTriggerHandler.handle(Trigger.operationType, Trigger.new, Trigger.oldMap);
}
