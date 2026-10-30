class ManagerTicketQueuePolicy
  def initialize(user, _record)
    @user = user
  end

  def index?
    %w[manager admin].include?(@user&.role)
  end
end
