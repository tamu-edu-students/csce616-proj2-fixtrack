require "spec_helper"
require "active_record"
require "sqlite3"
require_relative "../../app/queries/manager_ticket_queue"

# A separate connection exercises real SQL without booting the incomplete Rails
# model foundation or touching the application's development/test databases.
module ManagerTicketQueueSpec
  class Ticket < ActiveRecord::Base
    self.table_name = "tickets"
  end
end

RSpec.describe ManagerTicketQueue do
  let(:model) { ManagerTicketQueueSpec::Ticket }
  let(:now) { Time.utc(2026, 10, 30, 12) }

  before(:context) do
    ManagerTicketQueueSpec::Ticket.establish_connection(adapter: "sqlite3", database: ":memory:")
    ManagerTicketQueueSpec::Ticket.connection.create_table(:tickets) do |t|
      t.string :status
      t.string :priority
      t.integer :reporter_id
      t.datetime :created_at
    end
  end

  after(:context) { ManagerTicketQueueSpec::Ticket.remove_connection }
  before { model.delete_all }

  def create_ticket(status: "open", priority: "medium", created_at: now, reporter_id: 1)
    model.create!(status: status, priority: priority, created_at: created_at, reporter_id: reporter_id)
  end

  def queue(**options)
    described_class.new(scope: model.all, **options)
  end

  it "defaults to unresolved work across reporters" do
    active = %w[open assigned in_progress].each_with_index.map do |status, index|
      create_ticket(status: status, reporter_id: index + 1)
    end
    create_ticket(status: "resolved")

    expect(queue.tickets).to eq(active)
    expect(queue.status).to eq("open")
    expect(queue.sort).to eq("priority")
    expect(queue.page).to eq(1)
  end

  it "filters resolved tickets" do
    create_ticket
    resolved = create_ticket(status: "resolved")

    expect(queue(status: "resolved").tickets).to eq([ resolved ])
  end

  it "includes every status for the all filter" do
    tickets = %w[open assigned in_progress resolved].map { |status| create_ticket(status: status) }

    expect(queue(status: "all").tickets).to eq(tickets)
  end

  it "preserves the caller's visibility boundary" do
    visible = create_ticket(reporter_id: 1)
    create_ticket(reporter_id: 2)
    result = described_class.new(scope: model.where(reporter_id: 1), status: "all")

    expect(result.tickets).to eq([ visible ])
  end

  it "orders by priority, then oldest date, then ID" do
    low = create_ticket(priority: "low", created_at: now - 100)
    medium = create_ticket(priority: "medium", created_at: now - 50)
    high_new = create_ticket(priority: "high", created_at: now + 1)
    high_old = create_ticket(priority: "high")
    high_tie = create_ticket(priority: "high")

    expect(queue.tickets).to eq([ high_old, high_tie, high_new, medium, low ])
  end

  it "orders newest first with a descending ID tie breaker" do
    old = create_ticket(priority: "high", created_at: now - 1)
    first = create_ticket(priority: "low")
    second = create_ticket(priority: "low")

    expect(queue(sort: "newest").tickets).to eq([ second, first, old ])
  end

  it "orders oldest first with an ascending ID tie breaker" do
    new = create_ticket(priority: "high", created_at: now + 1)
    first = create_ticket(priority: "low")
    second = create_ticket(priority: "low")

    expect(queue(sort: "oldest").tickets).to eq([ first, second, new ])
  end

  it "replaces existing ordering without removing existing restrictions" do
    first = create_ticket
    second = create_ticket
    result = described_class.new(scope: model.order(id: :desc), sort: "oldest")

    expect(result.tickets).to eq([ first, second ])
  end

  it "defaults malformed filter and sort values without executing them as SQL" do
    active = create_ticket
    create_ticket(status: "resolved")

    [ nil, "", "unsupported", "resolved OR 1=1", [], {} ].each do |value|
      result = queue(status: value, sort: value)
      expect(result.status).to eq("open")
      expect(result.sort).to eq("priority")
      expect(result.tickets).to eq([ active ])
    end
  end

  it "defaults malformed or excessive page values to page one" do
    [ nil, "", "abc", "1.5", "2junk", "-1", "0", 0, [], {}, "9" * 100, described_class::MAX_PAGE + 1 ].each do |value|
      expect(queue(page: value).page).to eq(1)
    end
  end

  it "accepts positive integer pages from query strings or Ruby callers" do
    expect(queue(page: "2").page).to eq(2)
    expect(queue(page: 3).page).to eq(3)
  end

  it "accepts page 10,000 and resets larger pages to page one" do
    expect(queue(page: "10000").page).to eq(10_000)
    expect(queue(page: "10001").page).to eq(1)
  end

  it "returns an empty first page without navigation for an empty queue" do
    result = queue

    expect(result.tickets).to be_empty
    expect(result.next_page?).to be false
    expect(result.previous_page?).to be false
  end

  it "returns exactly 25 tickets without a next page when there are 25 matches" do
    25.times { create_ticket }
    result = queue

    expect(result.tickets.length).to eq(25)
    expect(result.next_page?).to be false
  end

  it "splits 26 matches across two pages without duplicates" do
    tickets = Array.new(26) { create_ticket }
    first_page = queue
    second_page = queue(page: "2")

    expect(first_page.tickets).to eq(tickets.first(25))
    expect(first_page.next_page?).to be true
    expect(first_page.previous_page?).to be false
    expect(second_page.tickets).to eq(tickets.last(1))
    expect(second_page.next_page?).to be false
    expect(second_page.previous_page?).to be true
  end

  it "does not offer a next page beyond the practical page cap" do
    stub_const("ManagerTicketQueue::MAX_PAGE", 1)
    26.times { create_ticket }

    expect(queue.next_page?).to be false
  end

  it "filters and orders before paginating" do
    26.times { create_ticket(status: "resolved") }
    active = Array.new(26) { |index| create_ticket(created_at: now + index) }
    result = queue(sort: "newest", page: "2")

    expect(result.tickets).to eq([ active.first ])
    expect(result.status).to eq("open")
    expect(result.sort).to eq("newest")
  end

  it "returns no tickets for an out-of-range page" do
    create_ticket
    result = queue(page: "100")

    expect(result.tickets).to be_empty
    expect(result.next_page?).to be false
    expect(result.previous_page?).to be true
  end

  it "fetches at most 26 rows and reuses them for pagination metadata" do
    30.times { create_ticket }
    statements = []
    subscriber = lambda do |*args|
      payload = args.last
      statements << payload[:sql] if payload[:sql].match?(/SELECT.*FROM "tickets"/)
    end
    result = queue

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      expect(result.tickets.length).to eq(25)
      expect(result.next_page?).to be true
      result.tickets
    end

    expect(statements.length).to eq(1)
    expect(statements.first).to include("LIMIT ?")
  end
end
