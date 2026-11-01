# Equipment management — issue #5

## Status

Implementation draft. Not ready to merge or deploy until issue #4 supplies
Devise authentication and role handling and the integration checks below pass.

## Authentication contract

The controller calls `authenticate_user!` before every action and expects
`current_user.manager?`. These are supplied by issue #4, not implemented here.
Coordinate with issue #7 before integrating shared authorization policies.
No login bypass is installed in application code.

Controller tests currently isolate this interface. They are not proof that real
login works. Repeat acceptance scenarios with actual users after #4 is integrated.

## Equipment rules

Confirmed by the issue owner: Available, Under Maintenance, Out of Service are
the equipment statuses, and asset identifiers must be unique. Identifiers have
surrounding whitespace removed; comparison is case-sensitive.

No maintenance-ticket model exists yet. The issue owner has deferred the
history-related deletion rule to the team. Recommended default: block deletion
when any tickets exist, using `dependent: :restrict_with_error` plus a database
foreign key. Confirm the rule and add real history-protection tests before
deploying ticket functionality. Do not introduce a cascading deletion of history.
Current deletion handles equipment records and propagates any future model
restriction errors; it does not decide the future ticket-retention policy.

## Using the feature

Visit /equipment after signing in. Authenticated users can list and view
equipment. Managers can add equipment, edit it, and follow Remove equipment to a
separate confirmation page. Cancel does not modify data. Confirm removal submits
a normal HTML form. No JavaScript is required.

Name, asset identifier, location and status are required. Description is optional.
Validation errors appear in a summary and beside the relevant fields.

## Verification

Local checks on 2026-10-20 used the available WSL Ruby 3.3.10 with Bundler
4.0.21; the repository's configured Ruby 4.0.6 is unchanged and still requires
verification. The equipment model/controller suite passed 37 examples with zero
failures. Its SimpleCov run measured 91.83% line coverage (45 of 49 lines).
This is not acceptance-test coverage or proof of real authentication integration.
The initial Ruby style check passed with no offenses. Cucumber's scaffold needed
the database_cleaner-active_record dependency, which is included in this draft.
Scripts are explicitly checked out with LF line endings for Linux compatibility.
After that setup repair, Cucumber loaded all 9 equipment scenarios. All 9 are
pending on issue #4 (42 subsequent steps skipped); none are claimed as passing.

Run with the Ruby version in .ruby-version and the locked Bundler version:

```sh
bundle install
bin/rails db:prepare
RAILS_ENV=test bin/rails db:prepare
bundle exec rspec spec/models/equipment_spec.rb spec/controllers/equipment_controller_spec.rb
bundle exec ruby script/check_equipment.rb
bundle exec cucumber features/equipment_management.feature
bin/rubocop
```

Before merge: integrate real authentication, verify
technician and anonymous requests using actual accounts, add ticket-history
restrictions when that model is available, check coverage, peer review and
production deployment.

## Equipment record metadata

Equipment records now support two optional fields:
- Manufacture date
- Specifications

Managers can enter or update these fields using the equipment form.
Authenticated technicians can view them but cannot modify equipment.
Missing values display “Not provided.” on the equipment details page.

The migration adds nullable columns, preserving existing records.
PDF/manual attachments and ticket-view integration remain outstanding.

Verification for this update:
- 42 model/controller examples passed.
- Full RuboCop check: 35 files inspected, no offenses.
- Targeted model/controller line coverage: 91.83%.

Authentication remains simulated in controller tests. Real-user
acceptance testing still depends on #4. These results do not establish
acceptance-test coverage or completion of the Definition of Done.
