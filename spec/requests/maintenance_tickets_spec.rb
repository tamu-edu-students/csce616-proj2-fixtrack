require 'rails_helper'

RSpec.describe "MaintenanceTickets", type: :request do
  describe "GET /index" do
    before do
      allow_any_instance_of(MaintenanceTicketsController).to receive(:authenticate_user!)
    end

    it "shows the issues landing page" do
      get "/issues"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Issues", "No issues have been reported.")
    end
  end
end
