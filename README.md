# ShipRight Operations Dashboard

An internal fulfillment platform for operations staff to manage customer orders from placement through delivery. Replaces the spreadsheet-based workflow with a Rails 8 monolith.

> This README has two halves: a **design proposal** (architecture, tradeoffs, decisions) and a **runbook** (setup, login, conventions). Read the proposal first if you're evaluating; jump to *Setup* if you just want it running.

---

## 1. Design Proposal

### 1.1 Stack

| Concern              | Choice                                                                 |
| -------------------- | ---------------------------------------------------------------------- |
| Framework            | Rails 8.1 (monolith), Ruby 3.4                                         |
| Database             | PostgreSQL 14+ (primary data)                                          |
| Background jobs      | Solid Queue (DB-backed; no Redis)                                      |
| Cache                | Solid Cache (DB-backed)                                                |
| Real-time UI         | Hotwire — Turbo Streams over Action Cable (Solid Cable)                |
| Auth                 | `has_secure_password` + session cookie. No self-serve registration.    |
| State machine        | Hand-rolled `OrderStateMachine` PORO (avoids gem lock-in for ~6 states) |
| Tests                | Minitest (Rails default), fixtures + system tests for critical paths   |
| Money                | `bigint` cents columns + `Money` value object                          |

**Why Rails 8 / Solid stack:** the assignment specifies Rails 8 and the brief explicitly says no Docker / no production config. Rails 8 ships Solid Queue + Solid Cache + Solid Cable as defaults, which means a single `bin/setup && bin/dev` boots the whole system — no Redis, no sidekiq config, no extra services for the evaluator. Same Postgres connection backs the queue, cache, and cable.

### 1.2 Domain Model

```
User (staff)
  └── has_many :audit_events  (as actor)

Customer
  └── has_many :orders

Product
  └── has_many :line_items

Order  ── belongs_to :customer
  ├── has_many :line_items
  ├── has_many :audit_events  (polymorphic, as :auditable)
  └── has_one  :shipment

Shipment ── belongs_to :order
  └── has_many :tracking_events
```

**Money:** `line_items.unit_price_cents` (bigint) + `currency` (string, default USD). Subtotals are derived in Ruby, never stored — single source of truth is the line item.

**Order status:** enum stored as **string**. States: `pending → approved → fulfilled → shipped → delivered`, plus a terminal `cancelled`. Strings (not integers) so the database is self-describing in psql, and reordering enum values doesn't silently corrupt history.

### 1.3 The Core: Order Lifecycle

The brief calls out lifecycle as "the core of the system" — this is where the design spends its complexity budget.

**Where the logic lives:** `app/models/concerns/order_state_machine.rb` — a concern mixed into `Order`. It declares allowed transitions as data:

```ruby
TRANSITIONS = {
  pending:   [:approved, :cancelled],
  approved:  [:fulfilled, :cancelled],
  fulfilled: [:shipped, :cancelled],
  shipped:   [:delivered],     # can't cancel once shipped
  delivered: [],               # terminal
  cancelled: []                # terminal
}.freeze
```

Each transition goes through one entry point — `order.transition_to!(:approved, actor: current_user)` — which:
1. Validates the transition is legal for the current state. Raises `Order::InvalidTransition` (a domain error, not an `ArgumentError`) if not.
2. Updates the status inside a DB transaction.
3. Records an `AuditEvent` capturing `from_state`, `to_state`, `actor`, and `occurred_at`.
4. Fires post-transition hooks (e.g., `:shipped` enqueues `TrackingSyncJob`).

**Why not a gem:** `aasm` / `state_machines` are great, but for 6 states with bespoke side effects (enqueue job, broadcast Turbo Stream, write audit row) the gem becomes a wrapper around 30 lines of logic. The PORO is more legible and easier for the next developer to grep.

**Invalid transitions in the UI:** The controller catches `Order::InvalidTransition` and re-renders with a flash. The user sees *"Cannot ship an order that hasn't been approved"* — never a 500.

### 1.4 Audit History — Built General-Purpose

The brief explicitly hints this requirement may apply to other models. So the audit layer is **not** order-specific.

**`Auditable` concern** (`app/models/concerns/auditable.rb`) — any model that includes it gets `has_many :audit_events, as: :auditable`. The single `AuditEvent` table is polymorphic:

```
audit_events
  - auditable_type, auditable_id   (polymorphic)
  - actor_type, actor_id           (polymorphic — usually User)
  - event                          (string: "status_changed", etc.)
  - from_state, to_state           (nullable, for transitions)
  - metadata                       (jsonb, for arbitrary context)
  - occurred_at
```

This is the "reusability" axis the rubric calls out — the same table covers shipment status changes, customer notes, future models without migration.

### 1.5 Carrier Tracking — Clean External Boundary

The brief: assume the API can fail, be slow, return junk. Don't block the user.

**Boundary:** `app/services/carriers/` — adapter pattern.

```
Carriers::Base                 # interface: fetch_tracking(tracking_number)
Carriers::FakeCarrier          # simulated; what we ship
Carriers::Response             # value object: events, status, raw_payload
```

**Sync flow:**
1. Order transitions to `:shipped`. `after_transition` enqueues `TrackingSyncJob`.
2. Job calls `Carriers::FakeCarrier.new.fetch_tracking(...)`.
3. Adapter wraps the network call in timeouts + error handling. On failure, returns `Carriers::Response.failed(...)` — never raises into the job.
4. On success, the job upserts `TrackingEvent` rows (idempotent on `external_id`) and broadcasts a Turbo Stream to `order_#{id}` so the detail page updates live.

**Why an adapter and not just a job:** when the real carrier ships, only `Carriers::FedEx < Carriers::Base` changes. The job, the model, the UI, the tests all stay put.

**Failure modes handled:**
- Network timeout → response with `success?: false`, error logged, job retries with backoff (Solid Queue `retry_on`).
- Malformed payload → caught at the adapter, never reaches the model.
- Duplicate events on retry → upsert by `external_id`.

### 1.6 Real-time Updates — Turbo Streams

Two places where the page updates without a refresh:

1. **Order detail page** subscribes via `turbo_stream_from @order`. When `TrackingSyncJob` finishes, it broadcasts a `replace` for the tracking timeline frame.
2. **Dashboard** subscribes to `orders:index`. Status transitions broadcast a row update.

Stimulus is used sparingly — bulk-select checkboxes and the actions dropdown.

### 1.7 Bulk Operations

`OrdersController#bulk_update` accepts `order_ids` + `action`. It's a thin wrapper around `Orders::BulkTransition` — a service object that:
- Loads all orders in one query.
- For each, attempts the transition; collects successes and failures.
- Renders a flash like *"Approved 7 orders. 2 skipped: #1042 (already shipped), #1051 (cancelled)."*

The same `transition_to!` path is used per-order — bulk doesn't bypass the state machine. This is critical: bulk is a UX affordance, not a separate code path.

### 1.8 Authentication

Rails 8 ships a generated authentication system (`bin/rails generate authentication`). I used it instead of Devise — fewer dependencies, the brief doesn't need password reset / email confirmation / OAuth. Sessions are DB-backed, sign-in is required for everything but `/session/new`.

No registration controller is wired up. Staff users are seeded; admins create accounts via the Rails console (documented below).

### 1.9 Tests

Critical paths (in priority order):

1. **State machine** — every legal transition, every illegal transition, audit row created.
2. **Bulk transition service** — partial success, all-fail, all-pass cases.
3. **Carrier adapter** — success, failure, idempotent retry.
4. **Authorization** — unauthenticated request redirects to sign-in.

Not covered (and noted): CSV export, fancy filtering combinations, performance under load.

### 1.10 What I'd Do With More Time

- Pundit (or generated `Authorization` concern) for role separation — currently every staff user can do everything.
- A proper `ransack`-style filter builder for the dashboard. Right now it's hand-rolled scopes for status only.
- Error tracking (Sentry/Honeybadger) hook in the carrier adapter.
- Pagination on the audit log per-order — fine for demo data, not for real volume.
- A real "needs my attention" inbox (the brief mentions "waiting on action from them") — currently approximated by status filter.

---

## 2. Setup

### Prerequisites

- Ruby 3.4 (`.ruby-version` pins it)
- PostgreSQL 14+ running on localhost:5432
- No Node required (importmaps)

### One-command setup

```
bin/setup
```

This installs gems, creates and migrates the database, seeds it, and prints the login credentials.

### Run

```
bin/dev
```

Boots Puma + Solid Queue worker. Open http://localhost:3000.

### Default Login

- **Email:** `staff@shipright.test`
- **Password:** `password`

Additional seeded users: `lead@shipright.test`, `ops@shipright.test` — same password.

### Creating new staff (no UI, by design)

```
bin/rails c
> User.create!(email_address: "new@shipright.test", password: "password", name: "New Staff")
```

### Tests

```
bin/rails test
```

---

## 3. Tradeoffs & Notes for the Evaluator

- **No real auth roles.** Every authenticated user is "staff". Adding Admin/Lead is a two-line addition once needed; deferred per "completeness of every edge case" being out of scope.
- **Carrier is simulated.** `Carriers::FakeCarrier` returns scripted events with a small random delay and a configurable failure rate so you can exercise the resilience path. Toggle in `config/initializers/carriers.rb`.
- **Money as cents.** Stored as `bigint`, presented via a small `Money` value object. No `money-rails` gem — the brief discourages prematurely reaching for tools.
- **Solid Queue runs in-process during dev** (`bin/dev` profile). In a real deploy you'd run a separate worker — but the brief says no production config.
- **Status filter is the only filter.** Date range / customer / search were out of scope for 8h.
- **Bulk action is approve-only in the UI.** The service handles all transitions; only "approve" is exposed because it's the most common bulk operation. Adding more is a view change.
