module Carriers
  module StatusMapper
    SHIPMENT_STATUS = {
      "label_created"    => "pending",
      "picked_up"        => "in_transit",
      "in_transit"       => "in_transit",
      "out_for_delivery" => "out_for_delivery",
      "delivered"        => "delivered",
      "exception"        => "exception"
    }.freeze

    module_function

    def shipment_status_for(carrier_status)
      SHIPMENT_STATUS.fetch(carrier_status.to_s, "in_transit")
    end
  end
end
