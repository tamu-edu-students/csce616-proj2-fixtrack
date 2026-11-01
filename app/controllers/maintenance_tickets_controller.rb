class MaintenanceTicketsController < ApplicationController
  before_action :authenticate_user!

  def new
    @maintenance_ticket = MaintenanceTicket.new
  end

  def create
    @maintenance_ticket = MaintenanceTicket.new(ticket_params)
    @maintenance_ticket.reporter = current_user

    if @maintenance_ticket.save
      redirect_to @maintenance_ticket,
                  notice: "Maintenance ticket created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @maintenance_ticket = MaintenanceTicket.find(params[:id])
  end

  private

  def ticket_params
    params.require(:maintenance_ticket).permit(
      :title,
      :description,
      :priority,
      :equipment_id
    )
  end
end
