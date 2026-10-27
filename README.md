# Record Lock Status for Salesforce Lightning

Salesforce Classic showed a padlock on locked records and gave admins an **Unlock Record** button. Lightning doesn't. This package brings both back.

It adds a small Lightning web component to any record page that can be locked:

- **Everyone** sees a red **Locked** or green **Unlocked** badge. It updates on its own when the record is saved.
- **Users with the Can Unlock Records permission** also get an **Unlock Record** button while the record is locked, with a confirmation step.
- **Everyone else** sees "Contact your admin if it needs changes," with no button.

The permission check happens in Apex, not just in the component, so users without the permission can't unlock records by any other route.

📖 **Full walkthrough with screenshots:** [Show Record Lock Status in Lightning (Plus an Unlock Button)](https://smcmigrations.com/salesforce-record-lock-status-unlock-button/)

## Download

**[RecordLockStatus_Workbench.zip](https://github.com/elisesfdc/record-lock-status-lwc/releases/latest/download/RecordLockStatus_Workbench.zip)**: deploy it as-is with Workbench. No code editing required.

## What's included

| Item | Type | What it does |
| --- | --- | --- |
| `recordLockStatus` | Lightning web component | The badge and Unlock button on the record page |
| `RecordLockStatusController` | Apex class | Checks lock status and handles unlocking |
| `RecordLockStatusControllerTest` | Apex test class | 8 tests, about 96% coverage |
| `Can_Unlock_Records` | Custom permission | Allows unlocking |
| `Record_Lock_Status_Viewer` | Permission set | Lets users see the badge. Assign to everyone who uses the page. |
| `Record_Lock_Status_Unlock` | Permission set | Shows the Unlock button and allows unlocking. Assign sparingly. |

## Before you install

Go to **Setup → Process Automation Settings** and check **Enable record locking and unlocking in Apex**. Without it, the component shows an error and the tests fail.

## Install with Workbench (no tools needed)

1. Download `RecordLockStatus_Workbench.zip` from the link above. Don't unzip it.
2. Log in to [Workbench](https://workbench.developerforce.com). Choose **Sandbox** for a sandbox, or **Production** for a Developer Edition org.
3. Go to **Migration → Deploy**, choose the zip, and check **Rollback On Error** and **Single Package**.
4. Click **Next**, then **Deploy**. Look for **Status: Succeeded** with 6 components deployed.
5. Run `RecordLockStatusControllerTest` in the Developer Console. All 8 tests should pass.
6. Assign **Record Lock Status - Viewer** to everyone who uses the page, and **Record Lock Status - Unlock** to the people who should be able to unlock.
7. Open a record, click **gear → Edit Page**, and drag **Record Lock Status** (under Custom) onto the page.

## Install with the Salesforce CLI

```bash
sf project deploy start --source-dir force-app --target-org <your-org-alias> --test-level RunSpecifiedTests --tests RecordLockStatusControllerTest
```

Then assign the permission sets and add the component to your record page (steps 6 and 7 above).

## Moving to production

Create an outbound change set with all six items above, and deploy it with **Run specified tests** → `RecordLockStatusControllerTest`. Permission set assignments don't travel in change sets, so assign them again in production.

## Works on any lockable object

Nothing in the code is specific to Cases. Drop the component on Opportunity, Account, custom object, or any other record page whose object supports locking. Two things to consider:

- One permission unlocks every object. If different teams should unlock different objects, you'll need to extend the code with per-object permissions.
- Approval processes lock records on purpose. Unlocking mid-approval lets people edit a record while it's under review, so be selective about who gets the Unlock permission set on those objects.

## Author

Built by Elise Pottinger, [SMC Migrations](https://smcmigrations.com) and [Salesforce Masterclass](https://salesforcemasterclass.com).
