require "rspec/expectations"
require "warden/test/helpers"

module EquipmentSteps
  def equipment_test_attributes
    { name: "Oscilloscope", asset_identifier: "LAB-001", location: "Lab A", status: "Available" }
  end

  def require_equipment_authentication
    pending "Blocked by issue #4: real User model and Devise user routes are not implemented." unless
      defined?(User) && Rails.application.routes.url_helpers.respond_to?(:new_user_session_path)
  end
end

World(EquipmentSteps)
World(Warden::Test::Helpers)
World(RSpec::Matchers)

Before("@equipment") { Warden.test_mode! }
After("@equipment") { Warden.test_reset! }

Given("I am authenticated for equipment management as a {string}") do |role|
  require_equipment_authentication
  attributes = { email: "equipment-#{role}@example.test", password: "Equipment-test-123!", role: role }
  attributes[:name] = "Equipment #{role}" if User.column_names.include?("name")
  user = User.create!(attributes)
  login_as(user, scope: :user)
end

Given("I am not authenticated for equipment management") do
  require_equipment_authentication
  logout(:user)
end

Given("an equipment record exists") do
  @equipment = Equipment.create!(equipment_test_attributes)
end

When("I visit the new equipment page") { visit new_equipment_path }
When("I visit the equipment edit page") { visit edit_equipment_path(@equipment) }
When("I visit the equipment details page") { visit equipment_path(@equipment) }
When("I visit the equipment list page") { visit equipment_index_path }
When("I visit the equipment removal confirmation page") { visit confirm_destroy_equipment_path(@equipment) }

When("I enter valid equipment information") do
  fill_in "Name", with: "Oscilloscope"
  fill_in "Asset identifier", with: "LAB-001"
  fill_in "Description", with: "Bench instrument"
  fill_in "Location", with: "Lab A"
  select "Available", from: "Status"
end

When("I enter equipment information without a name") do
  step "I enter valid equipment information"
  fill_in "Name", with: ""
end

When("I change the equipment location to {string}") { |location| fill_in "Location", with: location }
When("I press the equipment button {string}") { |label| click_button label }
When("I follow the equipment link {string}") { |label| click_link label }
Then("I should see the equipment text {string}") { |text| expect(page).to have_content(text) }
Then("I should not see the equipment text {string}") { |text| expect(page).not_to have_content(text) }

Then("the saved equipment should have location {string}") do |location|
  visit equipment_path(Equipment.find_by!(asset_identifier: "LAB-001"))
  expect(page).to have_content(location)
  expect(Equipment.find_by!(asset_identifier: "LAB-001").location).to eq(location)
end

Then("no equipment should have been saved") { expect(Equipment.count).to eq(0) }
Then("the equipment record should still exist") { expect(Equipment.exists?(@equipment.id)).to be(true) }

When("I directly attempt to {string} equipment") do |action|
  @equipment_snapshot = Equipment.order(:id).map(&:attributes)
  payload = { equipment: equipment_test_attributes.merge(name: "Unauthorized change") }
  method, path = case action
  when "create" then [ :post, equipment_index_path ]
  when "update" then [ :patch, equipment_path(@equipment) ]
  when "delete" then [ :delete, equipment_path(@equipment) ]
  end
  page.driver.submit(method, path, payload)
end

Then("the equipment response should be forbidden") { expect(page.status_code).to eq(403) }
Then("equipment data should be unchanged") { expect(Equipment.order(:id).map(&:attributes)).to eq(@equipment_snapshot) }
Then("I should be directed to the equipment sign in page") do
  expect(page).to have_current_path(new_user_session_path, ignore_query: true)
end
