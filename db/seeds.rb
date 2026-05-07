puts "Seeding ShipRight demo data..."

ActiveRecord::Base.transaction do
  TrackingEvent.delete_all
  Shipment.delete_all
  AuditEvent.delete_all
  LineItem.delete_all
  Order.delete_all
  Product.delete_all
  Customer.delete_all
  Session.delete_all
  User.delete_all

  # ---- Staff users ----------------------------------------------------------

  staff = User.create!(name: "Sam Staff", email_address: "staff@shipright.test", password: "password")
  User.create!(name: "Lee Lead", email_address: "lead@shipright.test", password: "password")
  User.create!(name: "Ola Ops",  email_address: "ops@shipright.test",  password: "password")

  # ---- Products -------------------------------------------------------------

  products = [
    { sku: "WIDGET-001", name: "Standard Widget",   unit_price_cents: 1999  },
    { sku: "WIDGET-PRO", name: "Pro Widget",        unit_price_cents: 4999  },
    { sku: "GADGET-XL",  name: "XL Gadget",         unit_price_cents: 8999  },
    { sku: "CABLE-USBC", name: "USB-C Cable, 2m",   unit_price_cents: 1299  },
    { sku: "DOCK-001",   name: "Desktop Dock",      unit_price_cents: 12500 },
    { sku: "CASE-MED",   name: "Carry Case (M)",    unit_price_cents: 3499  }
  ].map { |attrs| Product.create!(attrs) }

  # ---- Customers ------------------------------------------------------------

  customers = [
    { name: "Acme Industries", email: "ap@acme.test",        phone: "+1-555-0100" },
    { name: "Globex Corp",     email: "billing@globex.test", phone: "+1-555-0123" },
    { name: "Initech LLC",     email: "orders@initech.test", phone: "+1-555-0145" },
    { name: "Hooli",           email: "ops@hooli.test",      phone: "+1-555-0167" },
    { name: "Pied Piper",      email: "richard@pp.test",     phone: "+1-555-0189" },
    { name: "Soylent Corp",    email: "supply@soylent.test", phone: "+1-555-0201" }
  ].map { |attrs| Customer.create!(attrs) }

  # ---- Orders ---------------------------------------------------------------
  
  rng = Random.new(42)

  build_order = ->(customer, days_ago, item_specs) do
    placed_at = days_ago.days.ago
    order = Order.new(customer: customer, created_at: placed_at, updated_at: placed_at)
    item_specs.each { |product, qty| order.line_items.build(product: product, quantity: qty) }
    order.save!
    order
  end

  walk_through = ->(order, states) do
    states.each { |state| order.transition_to!(state, actor: staff, metadata: { source: "seed" }) }
  end

  2.times do
    customer = customers.sample(random: rng)
    items = products.sample(rng.rand(1..3), random: rng).map { |p| [ p, rng.rand(1..4) ] }
    build_order.call(customer, rng.rand(0..2), items)
  end

  2.times do
    o = build_order.call(customers.sample(random: rng), rng.rand(2..5),
                         products.sample(rng.rand(1..3), random: rng).map { |p| [ p, rng.rand(1..3) ] })
    walk_through.call(o, [ :approved ])
  end

  2.times do
    o = build_order.call(customers.sample(random: rng), rng.rand(3..6),
                         products.sample(rng.rand(1..3), random: rng).map { |p| [ p, rng.rand(1..3) ] })
    walk_through.call(o, [ :approved, :fulfilled ])
  end

  3.times do
    o = build_order.call(customers.sample(random: rng), rng.rand(4..10),
                         products.sample(rng.rand(1..4), random: rng).map { |p| [ p, rng.rand(1..3) ] })
    walk_through.call(o, [ :approved, :fulfilled, :shipped ])
    TrackingSyncJob.perform_now(o.shipment.id)
  end

  2.times do
    o = build_order.call(customers.sample(random: rng), rng.rand(8..14),
                         products.sample(rng.rand(1..3), random: rng).map { |p| [ p, rng.rand(1..2) ] })
    walk_through.call(o, [ :approved, :fulfilled, :shipped ])
    TrackingSyncJob.perform_now(o.shipment.id)
    o.transition_to!(:delivered, actor: staff, metadata: { source: "seed" }) if o.can_transition_to?(:delivered)
  end

  o = build_order.call(customers.sample(random: rng), 1, [ [ products.first, 1 ] ])
  walk_through.call(o, [ :cancelled ])
end

puts "Done."
puts "  Users:     #{User.count}"
puts "  Customers: #{Customer.count}"
puts "  Products:  #{Product.count}"
puts "  Orders:    #{Order.count} (#{Order.group(:status).count})"
puts ""
puts "Sign in with:"
puts "  email:    staff@shipright.test"
puts "  password: password"
