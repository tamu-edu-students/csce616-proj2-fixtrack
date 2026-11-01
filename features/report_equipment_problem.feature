Feature: Report an equipment problem
  As an authenticated user
  I want to create maintenance tickets
  So that equipment problems can be documented

  Scenario: Successfully report an equipment problem
    Given I am logged in as a technician
    And equipment named "Air Compressor" exists
    When I visit the new maintenance ticket page
    And I select "Air Compressor" as the equipment
    And I fill in "Problem Title" with "Motor failure"
    And I fill in "Problem Description" with "Motor does not start"
    And I select "High" as the priority
    And I submit the problem report
    Then I should see "Maintenance ticket created successfully."
    And I should see "Motor failure"

  Scenario: Reject a ticket without a title
    Given I am logged in as a technician
    And equipment named "Air Compressor" exists
    When I visit the new maintenance ticket page
    And I select "Air Compressor" as the equipment
    And I fill in "Problem Description" with "Motor does not start"
    And I select "High" as the priority
    And I submit the problem report
    Then I should see "Title can't be blank"

  Scenario: Prevent unauthenticated ticket creation
    Given I am not logged in
    When I visit the new maintenance ticket page
    Then I should be redirected to the login page
