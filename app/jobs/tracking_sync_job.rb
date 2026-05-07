class TrackingSyncJob < ApplicationJob
  queue_as :default

  def perform(shipment_id)
    shipment = Shipment.find_by(id: shipment_id)
    return if shipment.nil?

    response = carrier_for(shipment).fetch_tracking(shipment.tracking_number)

    if response.failed?
      shipment.update!(last_synced_at: Time.current, last_sync_error: response.error)
      broadcast_tracking_update(shipment)
      return
    end

    Shipment.transaction do
      upsert_events(shipment, response.events)
      shipment.update!(
        status: Carriers::StatusMapper.shipment_status_for(response.status),
        last_synced_at: Time.current,
        last_sync_error: nil
      )
    end

    broadcast_tracking_update(shipment)
    advance_order_if_delivered(shipment)
  end

  private

  def carrier_for(_shipment)
    Carriers::FakeCarrier.new
  end

  def upsert_events(shipment, events)
    events.each do |event|
      next if shipment.tracking_events.exists?(external_id: event.external_id)

      shipment.tracking_events.create!(
        external_id: event.external_id,
        status: event.status,
        location: event.location,
        description: event.description,
        occurred_at: event.occurred_at
      )
    end
  end

  def broadcast_tracking_update(shipment)
    Turbo::StreamsChannel.broadcast_replace_to(
      shipment.order,
      target: ActionView::RecordIdentifier.dom_id(shipment.order, :tracking),
      partial: "shipments/tracking",
      locals: { shipment: shipment }
    )
  rescue StandardError => e
    Rails.logger.warn("[TrackingSyncJob] broadcast failed: #{e.message}")
  end

  def advance_order_if_delivered(shipment)
    return unless shipment.status == "delivered"

    order = shipment.order
    return unless order.can_transition_to?(:delivered)

    order.transition_to!(:delivered, actor: nil, metadata: { source: "carrier_sync" })
  end
end
