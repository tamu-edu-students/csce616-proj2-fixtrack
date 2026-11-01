
require 'rails_helper'

RSpec.describe Company, type: :model do
  describe 'associations' do
    it 'has many users' do
      association = described_class.reflect_on_association(:users)

      expect(association.macro).to eq(:has_many)
    end

    it 'restricts deletion when users are associated' do
      association = described_class.reflect_on_association(:users)

      expect(association.options[:dependent]).to eq(:restrict_with_error)
    end
  end
end
