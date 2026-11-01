@equipment
Feature: Equipment management
  As a manager
  I want to create, view, update, and remove equipment records
  So that the organization's equipment information remains accurate

  Equipment records help the team locate assets and understand their current status.
  Authentication scenarios require the real login and User model from issue #4.

  Scenario: A manager creates and views equipment
    Given I am authenticated for equipment management as a "manager"
    When I visit the new equipment page
    And I enter valid equipment information
    And I press the equipment button "Create equipment"
    Then I should see the equipment text "Equipment created successfully."
    And the saved equipment should have location "Lab A"

  Scenario: Invalid equipment shows errors without creating a record
    Given I am authenticated for equipment management as a "manager"
    When I visit the new equipment page
    And I enter equipment information without a name
    And I press the equipment button "Create equipment"
    Then I should see the equipment text "Name can't be blank"
    And no equipment should have been saved

  Scenario: A manager updates equipment
    Given I am authenticated for equipment management as a "manager"
    And an equipment record exists
    When I visit the equipment edit page
    And I change the equipment location to "Lab B"
    And I press the equipment button "Save changes"
    Then the saved equipment should have location "Lab B"

  Scenario: A manager cancels equipment deletion
    Given I am authenticated for equipment management as a "manager"
    And an equipment record exists
    When I visit the equipment removal confirmation page
    And I follow the equipment link "Cancel"
    Then the equipment record should still exist

  Scenario: A manager confirms equipment deletion
    Given I am authenticated for equipment management as a "manager"
    And an equipment record exists
    When I visit the equipment removal confirmation page
    And I press the equipment button "Confirm removal"
    Then I should see the equipment text "Equipment removed successfully."
    And no equipment should have been saved

  Scenario: A technician can view equipment without modification controls
    Given I am authenticated for equipment management as a "technician"
    And an equipment record exists
    When I visit the equipment details page
    Then I should see the equipment text "Oscilloscope"
    And I should see the equipment text "Available"
    And I should not see the equipment text "Edit equipment"

  Scenario Outline: A technician cannot modify equipment through direct requests
    Given I am authenticated for equipment management as a "technician"
    And an equipment record exists
    When I directly attempt to "<action>" equipment
    Then the equipment response should be forbidden
    And equipment data should be unchanged

    Examples:
      | action |
      | create |
      | update |
      | delete |

  Scenario: Anonymous visitors must sign in
    Given I am not authenticated for equipment management
    When I visit the equipment list page
    Then I should be directed to the equipment sign in page
