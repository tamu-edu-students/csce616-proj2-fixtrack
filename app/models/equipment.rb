class Equipment < ApplicationRecord
  STATUSES = [ "Available", "Under Maintenance", "Out of Service" ].freeze

  normalizes :name, :asset_identifier, :location, with: ->(value) { value.strip }

  validates :name, :asset_identifier, :location, :status, presence: true
  validates :asset_identifier, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  # Ticket ownership and history restrictions will be added with the ticket model.
end
