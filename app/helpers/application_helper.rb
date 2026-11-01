module ApplicationHelper
  def manager_ticket_queue_access?
    user = current_user if respond_to?(:current_user)
    ManagerTicketQueuePolicy.new(user, :manager_ticket_queue).index?
  end
end
