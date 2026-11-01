class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  validates :name, presence: true
  validates :role, inclusion: { in: %w[manager technician reporter] }
  belongs_to :company, optional: true

  def manager?
    role == "manager"
  end
end
