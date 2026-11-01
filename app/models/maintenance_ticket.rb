class MaintenanceTicket < ApplicationRecord
  belongs_to :equipment
  belongs_to :reporter, class_name: "User"
  belongs_to :assigned_technician,
             class_name: "User",
             optional: true

  validates :title, presence: true
  validates :description, presence: true

  validates :priority,
            presence: true,
            inclusion: { in: %w[low medium high] }

  validates :status,
            presence: true,
            inclusion: {
              in: %w[open assigned in_progress resolved]
            }
end
