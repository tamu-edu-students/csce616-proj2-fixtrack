require "rails_helper"

RSpec.describe Equipment, type: :model do
  let(:attributes) do
    { name: "Oscilloscope", asset_identifier: "LAB-001", location: "Lab A", status: "Available" }
  end

  it "persists valid equipment with an optional description" do
    item = described_class.create!(attributes)
    expect(item.reload.attributes.symbolize_keys).to include(attributes)
    expect(item.description).to be_nil
  end

  [ :name, :asset_identifier, :location, :status ].each do |field|
    [ nil, "", "   " ].each do |value|
      it "rejects #{field} set to #{value.inspect}" do
        item = described_class.new(attributes.merge(field => value))
        expect(item).not_to be_valid
        expect(item.errors[field]).to be_present
      end
    end
  end

  it "rejects unsupported statuses" do
    expect(described_class.new(attributes.merge(status: "Broken"))).not_to be_valid
  end

  Equipment::STATUSES.each do |status|
    it "accepts the supported status #{status}" do
      expect(described_class.new(attributes.merge(status: status))).to be_valid
    end
  end

  it "strips surrounding whitespace from identifiers, names and locations" do
    item = described_class.create!(attributes.transform_values { |value| " #{value} " }.merge(status: "Available"))
    expect(item.reload.attributes.symbolize_keys).to include(attributes)
  end

  it "rejects duplicate normalized asset identifiers" do
    described_class.create!(attributes)
    item = described_class.new(attributes.merge(asset_identifier: " LAB-001 "))
    expect(item).not_to be_valid
    expect(item.errors[:asset_identifier]).to be_present
  end
end
