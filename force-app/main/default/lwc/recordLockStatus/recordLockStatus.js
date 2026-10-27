import { LightningElement, api, wire } from 'lwc';
import { getRecord, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import isRecordLocked from '@salesforce/apex/RecordLockStatusController.isRecordLocked';
import unlockRecord from '@salesforce/apex/RecordLockStatusController.unlockRecord';
import canUnlockPermission from '@salesforce/customPermission/Can_Unlock_Records';

export default class RecordLockStatus extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api cardTitle = 'Record Lock Status';

    isLocked;
    errorMessage;
    isLoading = true;
    isUnlocking = false;

    // Watch the record's LastModifiedDate. When the record is saved
    // (e.g. a user closes the Case and the flow locks it), this wire
    // fires again and the lock status is re-checked automatically.
    get optionalFields() {
        return this.objectApiName ? [`${this.objectApiName}.LastModifiedDate`] : [];
    }

    @wire(getRecord, { recordId: '$recordId', optionalFields: '$optionalFields' })
    wiredRecord({ data, error }) {
        if (data || error) {
            this.checkLockStatus();
        }
    }

    async checkLockStatus() {
        if (!this.recordId) {
            return;
        }
        this.isLoading = true;
        try {
            this.isLocked = await isRecordLocked({ recordId: this.recordId });
            this.errorMessage = undefined;
        } catch (e) {
            this.isLocked = undefined;
            this.errorMessage = this.reduceError(e, 'Unable to check lock status.');
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.checkLockStatus();
    }

    async handleUnlock() {
        const confirmed = await LightningConfirm.open({
            message: 'Unlocking lets anyone with edit access change this record again. Unlock it?',
            label: 'Unlock Record',
            theme: 'warning'
        });
        if (!confirmed) {
            return;
        }

        this.isUnlocking = true;
        try {
            this.isLocked = await unlockRecord({ recordId: this.recordId });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Record unlocked',
                message: 'This record can now be edited.',
                variant: 'success'
            }));
            // Let the rest of the page know the record changed
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Could not unlock record',
                message: this.reduceError(e, 'Something went wrong.'),
                variant: 'error'
            }));
            this.checkLockStatus();
        } finally {
            this.isUnlocking = false;
        }
    }

    reduceError(e, fallback) {
        return e?.body?.message || e?.message || fallback;
    }

    get hasStatus() {
        return !this.isLoading && !this.errorMessage && this.isLocked !== undefined;
    }

    // Unlock button: only when the record is locked AND the user has the permission
    get showUnlockButton() {
        return this.hasStatus && this.isLocked && canUnlockPermission;
    }

    get iconName() {
        return this.isLocked ? 'utility:lock' : 'utility:unlock';
    }

    get statusLabel() {
        return this.isLocked ? 'Locked' : 'Unlocked';
    }

    get badgeClass() {
        return this.isLocked ? 'slds-theme_error' : 'slds-theme_success';
    }

    get helpText() {
        if (!this.isLocked) {
            return 'This record can be edited normally.';
        }
        return canUnlockPermission
            ? 'This record is locked. You can unlock it if it needs changes.'
            : 'This record is locked. Contact your admin if it needs changes.';
    }
}
