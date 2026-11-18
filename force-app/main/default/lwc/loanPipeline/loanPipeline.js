/**
 * loanPipeline - Lightning Web Component
 * ----------------------------------------------------------------------------
 * A loan officer's work queue:
 *   - summary tiles (count + total $ by status)    -> @wire getPipelineSummary
 *   - filterable table of applications             -> @wire getApplications
 *   - row actions (Credit Review / Approve / Decline) -> imperative updateStatus
 *
 * Key LWC ideas shown here:
 *   @wire with a reactive parameter ('$selectedStatus') re-queries automatically
 *   refreshApex() re-fetches cached @wire data after a change
 *   imperative Apex calls return Promises (async/await)
 *   ShowToastEvent gives user feedback
 */
import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getApplications from '@salesforce/apex/LoanApplicationController.getApplications';
import getPipelineSummary from '@salesforce/apex/LoanApplicationController.getPipelineSummary';
import updateStatus from '@salesforce/apex/LoanApplicationController.updateStatus';

export const STATUSES = ['Draft', 'Submitted', 'Credit Review', 'Approved', 'Declined'];

const ROW_ACTIONS = [
    { label: 'Send to Credit Review', name: 'Credit Review' },
    { label: 'Approve', name: 'Approved' },
    { label: 'Decline', name: 'Declined' }
];

const COLUMNS = [
    { label: 'Application', fieldName: 'Name' },
    { label: 'Business', fieldName: 'accountName' },
    {
        label: 'Requested',
        fieldName: 'Requested_Amount__c',
        type: 'currency',
        typeAttributes: { currencyCode: 'CAD' }
    },
    { label: 'Status', fieldName: 'Status__c' },
    { label: 'Risk', fieldName: 'Risk_Rating__c' },
    { label: 'Score', fieldName: 'Risk_Score__c', type: 'number' },
    { label: 'Review Tier', fieldName: 'Review_Tier__c' },
    { type: 'action', typeAttributes: { rowActions: ROW_ACTIONS } }
];

const CURRENCY = new Intl.NumberFormat('en-CA', {
    style: 'currency',
    currency: 'CAD',
    maximumFractionDigits: 0
});

/** Turns the many shapes of Salesforce errors into one readable string. */
export function reduceError(error) {
    if (!error) {
        return 'Unknown error';
    }
    if (error.body) {
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error.body.message) {
            return error.body.message;
        }
    }
    return error.message || 'Unknown error';
}

export default class LoanPipeline extends LightningElement {
    columns = COLUMNS;
    statusOptions = [{ label: 'All', value: 'All' }].concat(STATUSES.map((s) => ({ label: s, value: s })));
    selectedStatus = 'All';

    rows = [];
    summary = [];
    error;
    isSaving = false;

    wiredAppsResult; // kept so refreshApex() can re-run the wire
    wiredSummaryResult;

    @wire(getApplications, { status: '$selectedStatus' })
    wiredApplications(result) {
        this.wiredAppsResult = result;
        if (result.data) {
            this.rows = result.data.map((row) => ({
                ...row,
                accountName: row.Account__r ? row.Account__r.Name : ''
            }));
            this.error = undefined;
        } else if (result.error) {
            this.rows = [];
            this.error = reduceError(result.error);
        }
    }

    @wire(getPipelineSummary)
    wiredSummary(result) {
        this.wiredSummaryResult = result;
        if (result.data) {
            const byStatus = new Map(result.data.map((s) => [s.status, s]));
            // Always show every status tile, in process order, even when 0.
            this.summary = STATUSES.map((status) => {
                const s = byStatus.get(status);
                return {
                    status,
                    total: s ? s.total : 0,
                    amountLabel: CURRENCY.format(s ? s.amount : 0)
                };
            });
        } else if (result.error) {
            this.error = reduceError(result.error);
        }
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value; // the @wire re-runs automatically
    }

    async handleRowAction(event) {
        const newStatus = event.detail.action.name;
        const row = event.detail.row;
        this.isSaving = true;
        try {
            await updateStatus({ applicationId: row.Id, newStatus });
            this.toast('Saved', `${row.Name} moved to ${newStatus}`, 'success');
            await Promise.all([refreshApex(this.wiredAppsResult), refreshApex(this.wiredSummaryResult)]);
        } catch (e) {
            this.toast('Could not update ' + row.Name, reduceError(e), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
