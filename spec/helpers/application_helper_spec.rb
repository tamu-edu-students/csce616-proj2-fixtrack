require "spec_helper"
require "action_view"
require "action_controller"
require_relative "../../app/helpers/application_helper"
require_relative "../../app/policies/manager_ticket_queue_policy"

RSpec.describe ApplicationHelper do
  let(:routes) do
    ActionDispatch::Routing::RouteSet.new.tap do |set|
      set.draw do
        namespace :manager do
          resources :maintenance_tickets, only: :index
        end
      end
    end
  end
  let(:view) do
    lookup = ActionView::LookupContext.new(File.expand_path("../../app/views", __dir__))
    ActionView::Base.with_empty_template_cache.new(lookup, {}, nil).tap do |instance|
      instance.extend(described_class)
      route_helpers = routes.url_helpers
      instance.define_singleton_method(:manager_maintenance_tickets_path) do
        route_helpers.manager_maintenance_tickets_path
      end
    end
  end

  %w[manager admin].each do |role|
    it "shows queue navigation to a #{role}" do
      view.define_singleton_method(:current_user) { Struct.new(:role).new(role) }

      expect(view.render(partial: "shared/navigation")).to include('href="/manager/maintenance_tickets"', "Ticket queue")
    end
  end

  [ "technician", "reporter", "unknown", nil ].each do |role|
    it "hides queue navigation for role #{role.inspect}" do
      view.define_singleton_method(:current_user) { Struct.new(:role).new(role) }

      expect(view.render(partial: "shared/navigation")).not_to include("Ticket queue")
    end
  end

  it "hides queue navigation when authentication helpers are unavailable" do
    expect(view.render(partial: "shared/navigation")).not_to include("Ticket queue")
  end
end
