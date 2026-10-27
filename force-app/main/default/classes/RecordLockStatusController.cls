/**
 * Apex controller for the recordLockStatus LWC.
 *
 * - isRecordLocked: anyone with access to this class can check lock status.
 * - unlockRecord:   only users with the Can_Unlock_Records custom permission
 *                   can unlock, and only records they can see. The checks
 *                   happen here on the server, so they can't be bypassed by
 *                   calling the method directly.
 *
 * Requires Setup > Process Automation Settings >
 * "Enable record locking and unlocking in Apex".
 */
public with sharing class RecordLockStatusController {

    @TestVisible
    private static final String UNLOCK_PERMISSION = 'Can_Unlock_Records';

    @AuraEnabled
    public static Boolean isRecordLocked(Id recordId) {
        if (recordId == null) {
            return false;
        }
        // If this throws (e.g. Apex locking isn't enabled), Salesforce's own
        // message is passed to the component, which is the most useful one.
        return Approval.isLocked(recordId);
    }

    /**
     * Unlocks the record and returns its new lock status (false on success).
     */
    @AuraEnabled
    public static Boolean unlockRecord(Id recordId) {
        if (!FeatureManagement.checkPermission(UNLOCK_PERMISSION)) {
            throw buildError('You don\'t have permission to unlock records.');
        }
        if (recordId == null) {
            throw buildError('No record ID was provided.');
        }

        // Only unlock records the user can actually see
        List<UserRecordAccess> access = [
            SELECT RecordId, HasReadAccess
            FROM UserRecordAccess
            WHERE UserId = :UserInfo.getUserId() AND RecordId = :recordId
        ];
        if (access.isEmpty() || !access[0].HasReadAccess) {
            throw buildError('You don\'t have access to this record.');
        }

        // Already unlocked: nothing to do (and avoids an "already unlocked" error)
        if (!Approval.isLocked(recordId)) {
            return false;
        }

        // Unlocking requires edit access, which non-admins never have on a
        // locked record. The permission and read-access checks above are the
        // gate, so the unlock itself runs without sharing.
        Approval.UnlockResult result = new SystemUnlocker().unlock(recordId);
        if (!result.isSuccess()) {
            throw buildError('Could not unlock record: ' + result.getErrors()[0].getMessage());
        }
        return Approval.isLocked(recordId);
    }

    private without sharing class SystemUnlocker {
        Approval.UnlockResult unlock(Id recordId) {
            return Approval.unlock(recordId, false);
        }
    }

    private static AuraHandledException buildError(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message); // so the message is readable in tests and logs
        return ex;
    }
}
