require "spec_helper"
require "action_controller"
require "rack/mock"
require "active_record"
require "pundit"
require "nokogiri"
require_relative "../../../app/helpers/application_helper"
require_relative "../../../app/policies/manager_ticket_queue_policy"
require_relative "../../../app/queries/manager_ticket_queue"

# Exercise the production controller with real HTTP requests and Pundit, while
# simulating the Devise boundary that is not yet integrated into main. Full
# application sign-in and database integration remain separate checks.
RSpec.describe "Manager ticket queue controller" do
  let(:user) { Struct.new(:role).new("manager") }
  let(:scope) { instance_double(ActiveRecord::Relation) }
  let(:query) do
    instance_double(ManagerTicketQueue, tickets: [], status: "open", sort: "priority",
      page: 1, previous_page?: false, next_page?: false)
  end

  before do
    base = Class.new(ActionController::Base) do
      def current_user
        request.env["queue_spec.user"]
      end

      def authenticate_user!
        redirect_to "/users/sign_in" unless current_user
      end
    end
    routes = ActionDispatch::Routing::RouteSet.new
    routes.draw do
      resources :maintenance_tickets, only: %i[new create show]
      namespace :manager do
        resources :maintenance_tickets, only: :index
      end
    end
    base.include(routes.url_helpers)
    base.helper(routes.url_helpers, ApplicationHelper)
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
        expect(body).to include("Manager ticket queue", "No unresolved tickets.")
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

  def document(query_string = "")
    Nokogiri::HTML(get_queue(query_string).last)
  end

  def ticket(id: 1, title: "Pump overheats", technician: nil)
    equipment = Struct.new(:name, :asset_identifier).new("Water pump", "PUMP-001")
    reporter = Struct.new(:name).new("Jamie Reporter")
    Struct.new(:id, :title, :equipment, :reporter, :priority, :status, :assigned_technician, :created_at)
      .new(id, title, equipment, reporter, "high", "in_progress", technician, Time.utc(2026, 10, 30, 12))
  end

  it "displays ticket details and a link to the shared detail page" do
    technician = Struct.new(:name).new("Alex Technician")
    allow(query).to receive(:tickets).and_return([ ticket(technician: technician) ])
    html = document

    expect(html.at_css('tbody a')["href"]).to eq("/maintenance_tickets/1")
    expect(html.at_css('tbody').text).to include("Pump overheats", "Water pump", "PUMP-001",
      "Jamie Reporter", "High", "In progress", "Alex Technician")
    expect(html.at_css('time')["datetime"]).to start_with("2026-10-30T12:00:00")
  end

  it "labels tickets without an assignee as Unassigned" do
    allow(query).to receive(:tickets).and_return([ ticket ])

    expect(document.at_css('tbody').text).to include("Unassigned")
  end

  it "escapes ticket text instead of rendering it as markup" do
    allow(query).to receive(:tickets).and_return([ ticket(title: '<script>alert("x")</script>') ])
    html = document

    expect(html.css('tbody script')).to be_empty
    expect(html.at_css('tbody').text).to include('<script>alert("x")</script>')
  end

  it "uses a GET form with selected filters and resets pagination on apply" do
    allow(query).to receive_messages(status: "resolved", sort: "newest", page: 2, previous_page?: true)
    html = document
    form = html.at_css('form')

    expect(form["method"]).to eq("get")
    expect(form["action"]).to eq("/manager/maintenance_tickets")
    expect(form.at_css('select[name="status"] option[selected]')["value"]).to eq("resolved")
    expect(form.at_css('select[name="sort"] option[selected]')["value"]).to eq("newest")
    expect(form.css('[name="page"]')).to be_empty
  end

  it "preserves filter and order selections in pagination links" do
    allow(query).to receive_messages(status: "resolved", sort: "newest", page: 2,
      previous_page?: true, next_page?: true)
    html = document
    previous_params = Rack::Utils.parse_query(URI(html.at_css('a[rel="prev"]')["href"]).query)
    next_params = Rack::Utils.parse_query(URI(html.at_css('a[rel="next"]')["href"]).query)

    expect(previous_params).to eq("status" => "resolved", "sort" => "newest", "page" => "1")
    expect(next_params).to eq("status" => "resolved", "sort" => "newest", "page" => "3")
  end

  it "hides pagination when there is only one page" do
    expect(document.css('nav[aria-label="Ticket queue pages"]')).to be_empty
  end

  { "open" => "No unresolved tickets.", "resolved" => "No resolved tickets.", "all" => "No tickets yet." }.each do |filter, message|
    it "explains empty results for the #{filter} filter" do
      allow(query).to receive(:status).and_return(filter)
      html = document

      expect(html.text).to include(message)
      expect(html.css('table')).to be_empty
      all_link = html.css('a').find { |link| link.text == "View all tickets" }
      if filter == "all"
        expect(all_link).to be_nil
      else
        expect(Rack::Utils.parse_query(URI(all_link["href"]).query)["status"]).to eq("all")
      end
    end
  end

  it "offers a return to page one for an empty out-of-range page" do
    allow(query).to receive_messages(status: "resolved", sort: "oldest", page: 100, previous_page?: true)
    html = document
    link = html.css('a').find { |element| element.text == "Back to first page" }

    expect(html.text).to include("No tickets on this page.")
    expect(Rack::Utils.parse_query(URI(link["href"]).query)).to eq("status" => "resolved", "sort" => "oldest")
  end
end
