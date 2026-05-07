module Carriers
  Event = Struct.new(:external_id, :status, :location, :description, :occurred_at, keyword_init: true)
end
