# User Guide

## Equipment management

See [Equipment management](equipment-management.md) for the draft CRUD workflow,
permissions, proposed statuses and authentication integration requirements.
This feature remains a development draft until its dependencies are integrated.

> **Status:** Placeholder. Add screenshots and verified workflows after the
> corresponding features are implemented.

## What Is FixTrack?

FixTrack centralizes equipment records and the maintenance process from
problem report through repair completion.

## Roles

### Admin

Your workflow is to provision the people who will use FixTrack:

1. Sign in with the initial Admin account.
2. Create users and assign each person the appropriate role.

Admins can provision Admins, Managers, Technicians, and Reporters.

### Manager

Your workflow is to coordinate equipment maintenance:

1. Manage the equipment records.
2. Review newly reported tickets.
3. Assign each ticket to a Technician.
4. Monitor ticket progress and repair history.

### Technician

Your workflow is to complete assigned repairs:

1. View the tickets assigned to you.
2. Update the ticket while working.
3. Record the repair work.
4. Send the repaired ticket to the Reporter for verification.

### Reporter

Your workflow is to report and verify equipment problems:

1. Find the equipment and open a ticket describing the problem.
2. View the progress of your submitted ticket.
3. Review the repair after the Technician sends it back.
4. Mark the ticket resolved if the problem is fixed, or reopen it with a
   reason if more work is needed.

## Overall Ticket Flow

`Reporter opens ticket` → `Manager assigns Technician` →
`Technician completes repair` → `Reporter verifies or reopens`

## Validation and Permissions

Required fields should display a clear validation message when omitted.
Unauthorized actions should be rejected and should not modify data.

> **TODO:** Add the actual sign-in, equipment, ticket, assignment, and repair
> screens with screenshots and field-level instructions.

## Troubleshooting

| Problem | Example next step |
| --- | --- |
| Cannot sign in | Verify credentials and confirm the account exists. |
| Cannot edit equipment | Confirm the account has the manager role. |
| Ticket is missing | Check the equipment and ticket filters. |
