module Manager
  class MaintenanceTicketsController < ApplicationController
    include Pundit::Authorization

    before_action :authenticate_user!
    after_action :verify_authorized

    rescue_from Pundit::NotAuthorizedError do
      render plain: "You are not allowed to access the manager ticket queue.", status: :forbidden
    end

    def index
      authorize :manager_ticket_queue

      @queue = ManagerTicketQueue.new(
        scope: queue_scope.preload(:equipment, :reporter, :assigned_technician),
        status: params[:status],
        sort: params[:sort],
        page: params[:page]
      )
      @tickets = @queue.tickets
    end

    private

    def queue_scope
      MaintenanceTicket.all
    end
  end
end
