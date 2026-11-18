/**
 * LoanRiskService
 * ----------------------------------------------------------------------------
 * Pure business logic: turns an application's financials into a 0-100 risk
 * score and a Low / Medium / High rating.
 *
 * Why a separate "service" class?
 *  - It does no SOQL and no DML, so it costs nothing against governor limits
 *    and can be unit-tested in memory (fast tests, no data setup).
 *  - The trigger handler, a batch job, or an LWC controller can all reuse it.
 *
 * The model below is deliberately simple and is NOT a real credit model.
 * Real banks use approved, validated models governed by model-risk policy.
 */
public with sharing class LoanRiskService {

    public static final Decimal HIGH_RISK_THRESHOLD = 60;
    public static final Decimal MEDIUM_RISK_THRESHOLD = 35;
    public static final Decimal MAX_SCORE = 100;

    /** Calculates and writes Risk_Score__c and Risk_Rating__c on each record (no DML). */
    public static void applyRisk(List<Loan_Application__c> applications) {
        for (Loan_Application__c app : applications) {
            Decimal score = calculateRiskScore(app);
            app.Risk_Score__c = score;
            app.Risk_Rating__c = ratingFor(score);
        }
    }

    /** Returns a score from 0 (lowest risk) to 100 (highest risk). */
    public static Decimal calculateRiskScore(Loan_Application__c app) {
        Decimal score = 0;

        // 1) Credit score (Canadian bureau range is 300-900). Lower = riskier.
        Integer credit = app.Credit_Score__c == null ? 0 : app.Credit_Score__c.intValue();
        if (credit < 600) {
            score += 40;
        } else if (credit < 680) {
            score += 25;
        } else if (credit < 750) {
            score += 10;
        }

        // 2) Leverage = (existing debt + new request) / annual revenue.
        Decimal revenue = app.Annual_Revenue__c;
        if (revenue == null || revenue <= 0) {
            score += 30; // no revenue on file is treated as maximum leverage risk
        } else {
            Decimal debt = app.Existing_Debt__c == null ? 0 : app.Existing_Debt__c;
            Decimal requested = app.Requested_Amount__c == null ? 0 : app.Requested_Amount__c;
            Decimal leverage = (debt + requested).divide(revenue, 4);
            if (leverage > 1) {
                score += 30;
            } else if (leverage > 0.5) {
                score += 15;
            } else if (leverage > 0.25) {
                score += 5;
            }
        }

        // 3) Time in business. Young businesses fail more often.
        Decimal years = app.Years_In_Business__c == null ? 0 : app.Years_In_Business__c;
        if (years < 2) {
            score += 20;
        } else if (years < 5) {
            score += 10;
        }

        return score > MAX_SCORE ? MAX_SCORE : score;
    }

    public static String ratingFor(Decimal score) {
        if (score == null) {
            return null;
        }
        if (score >= HIGH_RISK_THRESHOLD) {
            return 'High';
        }
        if (score >= MEDIUM_RISK_THRESHOLD) {
            return 'Medium';
        }
        return 'Low';
    }
}
