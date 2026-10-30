require "spec_helper"
require_relative "../../app/policies/manager_ticket_queue_policy"

RSpec.describe ManagerTicketQueuePolicy do
  subject(:policy) { described_class.new(user, :manager_ticket_queue) }

  let(:user) { Struct.new(:role).new(role) }

  describe "#index?" do
    %w[manager admin].each do |allowed_role|
      context "with a #{allowed_role}" do
        let(:role) { allowed_role }

        it "allows queue access" do
          expect(policy.index?).to be true
        end
      end
    end

    [ "technician", "reporter", "unknown", nil ].each do |denied_role|
      context "with role #{denied_role.inspect}" do
        let(:role) { denied_role }

        it "denies queue access" do
          expect(policy.index?).to be false
        end
      end
    end

    context "without a signed-in user" do
      let(:user) { nil }

      it "denies queue access" do
        expect(policy.index?).to be false
      end
    end
  end
end
