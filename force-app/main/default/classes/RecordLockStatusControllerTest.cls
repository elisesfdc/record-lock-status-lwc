@IsTest
private class RecordLockStatusControllerTest {

    // ---------- helpers ----------

    private static User createUser(String alias, Boolean canUnlock) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String unique = alias + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            Alias = alias,
            Email = unique + '@example.com',
            Username = unique + '@locktest.example.com',
            LastName = 'LockTest',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;

        List<PermissionSetAssignment> psas = new List<PermissionSetAssignment>();
        List<String> permSetNames = new List<String>{ 'Record_Lock_Status_Viewer' };
        if (canUnlock) {
            permSetNames.add('Record_Lock_Status_Unlock');
        }
        for (PermissionSet ps : [SELECT Id FROM PermissionSet WHERE Name IN :permSetNames]) {
            psas.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id));
        }
        insert psas;
        return u;
    }

    private static Case createLockedCase(Boolean lockIt) {
        Case c = new Case(Subject = 'Lock Status Test', Status = 'New', Origin = 'Phone');
        insert c;
        if (lockIt) {
            Approval.lock(c.Id);
        }
        return c;
    }

    // ---------- isRecordLocked ----------

    @IsTest
    static void isRecordLocked_returnsFalseWhenUnlocked() {
        Case c = createLockedCase(false);
        Test.startTest();
        Boolean result = RecordLockStatusController.isRecordLocked(c.Id);
        Test.stopTest();
        System.assertEquals(false, result);
    }

    @IsTest
    static void isRecordLocked_returnsTrueWhenLocked() {
        Case c = createLockedCase(true);
        Test.startTest();
        Boolean result = RecordLockStatusController.isRecordLocked(c.Id);
        Test.stopTest();
        System.assertEquals(true, result);
    }

    @IsTest
    static void isRecordLocked_returnsFalseForNullId() {
        System.assertEquals(false, RecordLockStatusController.isRecordLocked(null));
    }

    // ---------- unlockRecord ----------

    @IsTest
    static void unlockRecord_unlocksWhenUserHasPermission() {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            u = createUser('unlk', true);
        }
        System.runAs(u) {
            Case c = createLockedCase(true);
            Test.startTest();
            Boolean stillLocked = RecordLockStatusController.unlockRecord(c.Id);
            Test.stopTest();
            System.assertEquals(false, stillLocked, 'Record should be unlocked');
            System.assertEquals(false, Approval.isLocked(c.Id));
        }
    }

    @IsTest
    static void unlockRecord_blockedWithoutPermission() {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            u = createUser('nounlk', false);
        }
        System.runAs(u) {
            Case c = createLockedCase(true);
            Boolean threw = false;
            Test.startTest();
            try {
                RecordLockStatusController.unlockRecord(c.Id);
            } catch (AuraHandledException e) {
                threw = true;
                System.assert(e.getMessage().contains('permission'), e.getMessage());
            }
            Test.stopTest();
            System.assert(threw, 'Users without the permission must not unlock');
            System.assertEquals(true, Approval.isLocked(c.Id), 'Record should still be locked');
        }
    }

    @IsTest
    static void unlockRecord_alreadyUnlockedReturnsFalse() {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            u = createUser('unlk2', true);
        }
        System.runAs(u) {
            Case c = createLockedCase(false);
            Test.startTest();
            Boolean stillLocked = RecordLockStatusController.unlockRecord(c.Id);
            Test.stopTest();
            System.assertEquals(false, stillLocked);
        }
    }

    @IsTest
    static void unlockRecord_blockedWhenUserCannotSeeRecord() {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            u = createUser('unlk4', true);
        }

        // A permanently deleted record is one nobody can see
        Case c = createLockedCase(false);
        Id deletedId = c.Id;
        delete c;
        Database.emptyRecycleBin(new List<Id>{ deletedId });

        System.runAs(u) {
            Boolean threw = false;
            Test.startTest();
            try {
                RecordLockStatusController.unlockRecord(deletedId);
            } catch (Exception e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw, 'Unlocking a record the user cannot see should fail');
        }
    }

    @IsTest
    static void unlockRecord_nullIdThrows() {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            u = createUser('unlk3', true);
        }
        System.runAs(u) {
            Boolean threw = false;
            try {
                RecordLockStatusController.unlockRecord(null);
            } catch (AuraHandledException e) {
                threw = true;
            }
            System.assert(threw, 'Null ID should throw');
        }
    }
}
