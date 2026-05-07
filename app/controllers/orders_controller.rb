class OrdersController < ApplicationController
  before_action :set_order, only: %i[show transition sync_tracking]

  def index
    @status_filter = filter_status
    @orders = Order.includes(:customer, :line_items, :shipment).order(created_at: :desc)
    @orders = @orders.where(status: @status_filter) if @status_filter

    @counts_by_status = Order.group(:status).count
  end

  def show
    @audit_events = @order.audit_events.includes(:actor).recent.limit(50)
  end

  def transition
    target = params.require(:state).to_sym
    @order.transition_to!(target, actor: current_user)

    respond_to do |format|
      format.html { redirect_to @order, notice: "Order moved to #{target}." }
      format.turbo_stream { flash.now[:notice] = "Order moved to #{target}." }
    end
  rescue OrderStateMachine::InvalidTransition => e
    respond_to do |format|
      format.html { redirect_to @order, alert: e.message }
      format.turbo_stream { flash.now[:alert] = e.message }
    end
  end

  def sync_tracking
    if @order.shipment.present?
      TrackingSyncJob.perform_later(@order.shipment.id)
      redirect_to @order, notice: "Tracking sync queued."
    else
      redirect_to @order, alert: "No shipment yet — order has not shipped."
    end
  end

  def bulk_update
    target = params.require(:state).to_sym
    ids = Array(params[:order_ids]).reject(&:blank?)

    if ids.empty?
      redirect_to orders_path, alert: "Select at least one order." and return
    end

    orders = Order.where(id: ids)
    result = Orders::BulkTransition.new(orders: orders, target_state: target, actor: current_user).call

    flash[:notice] = result.summary if result.succeeded.any?
    flash[:alert]  = result.failure_details.join(" • ") if result.failed.any?

    redirect_to orders_path
  end

  private

  ALLOWED_FILTERS = OrderStateMachine::STATES.map(&:to_s).freeze

  def filter_status
    return nil if params[:status].blank? || params[:status] == "all"

    ALLOWED_FILTERS.include?(params[:status]) ? params[:status] : nil
  end

  def set_order
    @order = Order.includes(line_items: :product).find(params[:id])
  end
end
