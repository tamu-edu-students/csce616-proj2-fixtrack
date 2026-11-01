
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      user = User.new(
        name: 'Bruce Wayne',
        email: 'batman@example.com',
        password: 'password123',
        role: 'technician'
      )

      expect(user).to be_valid
    end

    it 'is invalid without a name' do
      user = User.new(
        name: nil,
        email: 'batman@example.com',
        role: 'technician'
      )

      expect(user).not_to be_valid
      expect(user.errors[:name]).to include("can't be blank")
    end

    it 'is invalid without an email' do
      user = User.new(
        name: 'Bruce Wayne',
        email: nil,
        role: 'technician'
      )

      expect(user).not_to be_valid
    end

    it 'is invalid with an unsupported role' do
      user = User.new(
        name: 'Bruce Wayne',
        email: 'batman@example.com',
        role: 'admin'
      )

      expect(user).not_to be_valid
    end
  end
end
