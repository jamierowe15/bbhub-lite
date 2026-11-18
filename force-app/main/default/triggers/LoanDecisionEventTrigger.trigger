/**
 * Platform event subscriber. Platform event triggers only support "after insert".
 */
trigger LoanDecisionEventTrigger on Loan_Decision__e (after insert) {
    LoanDecisionEventHandler.handle(Trigger.new);
}
