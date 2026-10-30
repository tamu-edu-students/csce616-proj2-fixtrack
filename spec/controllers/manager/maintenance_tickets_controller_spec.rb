require "spec_helper"
require "action_controller"
require "rack/mock"
require "active_record"
require "pundit"
require_relative "../../../app/policies/manager_ticket_queue_policy"
require_relative "../../../app/queries/manager_ticket_queue"

# Exercise the production controller with real HTTP requests and Pundit, while
# simulating the Devise boundary that is not yet integrated into main. Full
# application sign-in and database integration remain separate checks.
RSpec.describe "Manager ticket queue controller" do
  let(:user) { Struct.new(:role).new("manager") }
  let(:scope) { instance_double(ActiveRecord::Relation) }
  let(:query) { instance_double(ManagerTicketQueue, tickets: []) }

  before do
    base = Class.new(ActionController::Base) do
      def current_user
        request.env["queue_spec.user"]
      end

      def authenticate_user!
        redirect_to "/users/sign_in" unless current_user
      end
    end
    stub_const("ApplicationController", base)
    stub_const("Manager", Module.new)
    stub_const("MaintenanceTicket", Class.new(ActiveRecord::Base))
    load File.expand_path("../../../app/controllers/manager/maintenance_tickets_controller.rb", __dir__)
    Manager::MaintenanceTicketsController.append_view_path(File.expand_path("../../../app/views", __dir__))

    allow(MaintenanceTicket).to receive(:all).and_return(scope)
    allow(scope).to receive(:preload).with(:equipment, :reporter, :assigned_technician).and_return(scope)
    allow(ManagerTicketQueue).to receive(:new).and_return(query)
  end

  def get_queue(query_string = "")
    env = Rack::MockRequest.env_for("/manager/maintenance_tickets#{query_string}")
    env["queue_spec.user"] = user
    status, headers, body = Manager::MaintenanceTicketsController.action(:index).call(env)
    content = body.each.to_a.join
    body.close if body.respond_to?(:close)
    [ status, headers, content ]
  end

  %w[manager admin].each do |role|
    context "as a #{role}" do
      let(:user) { Struct.new(:role).new(role) }

      it "renders the queue" do
        status, _headers, body = get_queue

        expect(status).to eq(200)
        expect(body).to include("Manager ticket queue", "0 tickets on this page.")
      end
    end
  end

  %w[technician reporter unknown].each do |role|
    context "as a #{role}" do
      let(:user) { Struct.new(:role).new(role) }

      it "denies access before loading any tickets" do
        expect(MaintenanceTicket).not_to receive(:all)
        expect(ManagerTicketQueue).not_to receive(:new)

        status, _headers, body = get_queue

        expect(status).to eq(403)
        expect(body).to include("You are not allowed to access the manager ticket queue.")
      end
    end
  end

  context "without a signed-in user" do
    let(:user) { nil }

    it "authenticates before loading the queue" do
      expect(MaintenanceTicket).not_to receive(:all)
      expect(ManagerTicketQueue).not_to receive(:new)

      status, headers, _body = get_queue

      expect(status).to eq(302)
      expect(headers["location"]).to end_with("/users/sign_in")
    end
  end

  it "passes supported request parameters into the queue with preloaded associations" do
    expect(scope).to receive(:preload).with(:equipment, :reporter, :assigned_technician).and_return(scope)
    expect(ManagerTicketQueue).to receive(:new).with(
      scope: scope, status: "resolved", sort: "newest", page: "2"
    ).and_return(query)

    expect(get_queue("?status=resolved&sort=newest&page=2").first).to eq(200)
  end

  it "does not pass arbitrary request parameters into the query" do
    expect(ManagerTicketQueue).to receive(:new).with(
      scope: scope, status: nil, sort: nil, page: nil
    ).and_return(query)

    expect(get_queue("?reporter_id=123&company_id=456").first).to eq(200)
  end
end
