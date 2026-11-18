/**
 * Jest unit tests for loanPipeline. These run on your PC with Node,
 * with no Salesforce org needed:  npm run test:unit
 */
import { createElement } from 'lwc';
import LoanPipeline, { reduceError } from 'c/loanPipeline';
import getApplications from '@salesforce/apex/LoanApplicationController.getApplications';
import getPipelineSummary from '@salesforce/apex/LoanApplicationController.getPipelineSummary';
import updateStatus from '@salesforce/apex/LoanApplicationController.updateStatus';
// The toast stub fires this event name when ShowToastEvent is dispatched.
const ShowToastEventName = 'lightning__showtoast';

// Wire adapters: let the test "emit" data as if Apex returned it.
jest.mock(
    '@salesforce/apex/LoanApplicationController.getApplications',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/LoanApplicationController.getPipelineSummary',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
// Imperative Apex: a plain jest.fn returning a Promise.
jest.mock(
    '@salesforce/apex/LoanApplicationController.updateStatus',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock('@salesforce/apex', () => ({ refreshApex: jest.fn(() => Promise.resolve()) }), { virtual: true });

const APPS = [
    {
        Id: 'a01000000000001AAA',
        Name: 'LA-0001',
        Account__r: { Name: 'Maple Leaf Bakery' },
        Requested_Amount__c: 150000,
        Status__c: 'Submitted',
        Risk_Rating__c: 'Low',
        Risk_Score__c: 10,
        Review_Tier__c: 'Branch Lending'
    },
    {
        Id: 'a01000000000002AAA',
        Name: 'LA-0002',
        Requested_Amount__c: 1500000,
        Status__c: 'Credit Review',
        Risk_Rating__c: 'High',
        Risk_Score__c: 70,
        Review_Tier__c: 'Executive Credit Committee'
    }
];
const SUMMARY = [
    { status: 'Submitted', total: 1, amount: 150000 },
    { status: 'Credit Review', total: 1, amount: 1500000 }
];

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

function mount() {
    const el = createElement('c-loan-pipeline', { is: LoanPipeline });
    document.body.appendChild(el);
    return el;
}

describe('c-loan-pipeline', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders one tile per status, including zero counts', async () => {
        const el = mount();
        getPipelineSummary.emit(SUMMARY);
        await flushPromises();

        const tiles = el.shadowRoot.querySelectorAll('.tile');
        expect(tiles.length).toBe(5);
        const submitted = el.shadowRoot.querySelector('.tile[data-status="Submitted"] .tile-total');
        const approved = el.shadowRoot.querySelector('.tile[data-status="Approved"] .tile-total');
        expect(submitted.textContent).toBe('1');
        expect(approved.textContent).toBe('0');
    });

    it('shows the datatable with flattened account names', async () => {
        const el = mount();
        getApplications.emit(APPS);
        await flushPromises();

        const table = el.shadowRoot.querySelector('lightning-datatable');
        expect(table).not.toBeNull();
        expect(table.data.length).toBe(2);
        expect(table.data[0].accountName).toBe('Maple Leaf Bakery');
        expect(table.data[1].accountName).toBe('');
    });

    it('shows the empty message when there are no rows', async () => {
        const el = mount();
        getApplications.emit([]);
        await flushPromises();
        expect(el.shadowRoot.querySelector('lightning-datatable')).toBeNull();
        expect(el.shadowRoot.querySelector('.empty-message')).not.toBeNull();
    });

    it('re-queries with the selected status when the filter changes', async () => {
        const el = mount();
        await flushPromises();
        const combo = el.shadowRoot.querySelector('lightning-combobox');
        combo.dispatchEvent(new CustomEvent('change', { detail: { value: 'Approved' } }));
        await flushPromises();
        expect(getApplications.getLastConfig()).toEqual({ status: 'Approved' });
    });

    it('shows an error message when Apex fails', async () => {
        const el = mount();
        getApplications.error({ message: 'Insufficient access' });
        await flushPromises();
        const err = el.shadowRoot.querySelector('.error-message');
        expect(err.textContent).toContain('Insufficient access');
    });

    it('approves a row, shows a success toast and refreshes', async () => {
        updateStatus.mockResolvedValue(undefined);
        const el = mount();
        getApplications.emit(APPS);
        await flushPromises();

        const toastHandler = jest.fn();
        el.addEventListener(ShowToastEventName, toastHandler);

        const table = el.shadowRoot.querySelector('lightning-datatable');
        table.dispatchEvent(
            new CustomEvent('rowaction', { detail: { action: { name: 'Approved' }, row: APPS[0] } })
        );
        await flushPromises();

        expect(updateStatus).toHaveBeenCalledWith({ applicationId: APPS[0].Id, newStatus: 'Approved' });
        expect(toastHandler).toHaveBeenCalledTimes(1);
        expect(toastHandler.mock.calls[0][0].detail.variant).toBe('success');
    });

    it('shows an error toast when the server rejects the change', async () => {
        updateStatus.mockRejectedValue({ body: { message: 'Only Submitted or Credit Review applications can be Approved.' } });
        const el = mount();
        getApplications.emit(APPS);
        await flushPromises();

        const toastHandler = jest.fn();
        el.addEventListener(ShowToastEventName, toastHandler);
        el.shadowRoot
            .querySelector('lightning-datatable')
            .dispatchEvent(new CustomEvent('rowaction', { detail: { action: { name: 'Approved' }, row: APPS[0] } }));
        await flushPromises();

        const detail = toastHandler.mock.calls[0][0].detail;
        expect(detail.variant).toBe('error');
        expect(detail.message).toContain('Only Submitted');
    });
});

describe('reduceError', () => {
    it('handles the common Salesforce error shapes', () => {
        expect(reduceError(undefined)).toBe('Unknown error');
        expect(reduceError({ body: { message: 'A' } })).toBe('A');
        expect(reduceError({ body: [{ message: 'A' }, { message: 'B' }] })).toBe('A, B');
        expect(reduceError({ message: 'C' })).toBe('C');
    });
});
