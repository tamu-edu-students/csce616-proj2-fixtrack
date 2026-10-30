class ManagerTicketQueue
  PAGE_SIZE = 25
  STATUS_OPTIONS = %w[open resolved all].freeze
  SORT_OPTIONS = %w[priority newest oldest].freeze
  OPEN_STATUSES = %w[open assigned in_progress].freeze
  # Bound pagination to a practical number of pages.
  MAX_PAGE = 10_000

  attr_reader :status, :sort, :page

  def initialize(scope:, status: nil, sort: nil, page: nil)
    @scope = scope
    @status = STATUS_OPTIONS.include?(status) ? status : "open"
    @sort = SORT_OPTIONS.include?(sort) ? sort : "priority"
    @page = normalize_page(page)
  end

  def tickets
    page_rows.first(PAGE_SIZE)
  end

  def next_page?
    page_rows.length > PAGE_SIZE
  end

  def previous_page?
    page > 1
  end

  private

  def normalize_page(value)
    return 1 unless value.is_a?(String) || value.is_a?(Integer)
    return 1 unless value.to_s.match?(/\A[0-9]{1,19}\z/)

    number = value.to_i
    number.between?(1, MAX_PAGE) ? number : 1
  end

  def filtered_scope
    case status
    when "open" then @scope.where(status: OPEN_STATUSES)
    when "resolved" then @scope.where(status: "resolved")
    else @scope
    end
  end

  def ordering
    table = @scope.klass.arel_table
    case sort
    when "newest"
      [ table[:created_at].desc, table[:id].desc ]
    when "oldest"
      [ table[:created_at].asc, table[:id].asc ]
    else
      priority = Arel::Nodes::Case.new(table[:priority])
        .when("high").then(0).when("medium").then(1).when("low").then(2).else(3)
      [ priority.asc, table[:created_at].asc, table[:id].asc ]
    end
  end

  def page_rows
    @page_rows ||= filtered_scope.reorder(*ordering)
      .offset((page - 1) * PAGE_SIZE).limit(PAGE_SIZE + 1).to_a
  end
end
