module OrderStateMachine
  extend ActiveSupport::Concern

  STATES = %i[pending approved fulfilled shipped delivered cancelled].freeze

  TRANSITIONS = {
    pending:   %i[approved cancelled],
    approved:  %i[fulfilled cancelled],
    fulfilled: %i[shipped cancelled],
    shipped:   %i[delivered],
    delivered: [],
    cancelled: []
  }.freeze

  REJECTION_MESSAGES = {
    [:pending,   :fulfilled] => "Order must be approved before it can be fulfilled.",
    [:pending,   :shipped]   => "Order must be approved and fulfilled before it can be shipped.",
    [:pending,   :delivered] => "Order must be shipped before it can be marked delivered.",
    [:approved,  :shipped]   => "Order must be fulfilled before it can be shipped.",
    [:approved,  :delivered] => "Order must be shipped before it can be marked delivered.",
    [:fulfilled, :delivered] => "Order must be shipped before it can be marked delivered.",
    [:shipped,   :cancelled] => "Cannot cancel an order that has already shipped.",
    [:delivered, :cancelled] => "Cannot cancel a delivered order.",
    [:cancelled, :approved]  => "Cannot reactivate a cancelled order."
  }.freeze

  class InvalidTransition < StandardError
    attr_reader :order, :from, :to

    def initialize(order:, from:, to:)
      @order = order
      @from = from.to_sym
      @to = to.to_sym
      super(build_message)
    end

    private

    def build_message
      REJECTION_MESSAGES[[from, to]] ||
        "Cannot move order from #{from} to #{to}."
    end
  end

  included do
    validates :status, inclusion: { in: STATES.map(&:to_s) }

    STATES.each do |state|
      scope state, -> { where(status: state.to_s) }
      define_method("#{state}?") { status.to_s == state.to_s }
    end
  end

  class_methods do
    # Subclasses register hooks via `after_transition_to(:shipped) { ... }`.
    # Hooks are stored on the class so each Order subclass / inclusion gets its
    # own list — and they always run inside the DB transaction that performed
    # the transition (so a hook failure rolls back the status change).
    def after_transition_to(target_state, &block)
      transition_hooks[target_state.to_sym] << block
    end

    def transition_hooks
      @transition_hooks ||= Hash.new { |h, k| h[k] = [] }
    end
  end

  def status_sym
    status.to_sym
  end

  def can_transition_to?(target)
    TRANSITIONS.fetch(status_sym, []).include?(target.to_sym)
  end

  def available_transitions
    TRANSITIONS.fetch(status_sym, []).dup
  end

  def transition_to!(target, actor: nil, metadata: {})
    target = target.to_sym
    from   = status_sym

    unless can_transition_to?(target)
      raise InvalidTransition.new(order: self, from: from, to: target)
    end

    transaction do
      update!(status: target.to_s)

      record_audit_event!(
        event: "status_changed",
        actor: actor,
        from_state: from,
        to_state: target,
        metadata: metadata
      )

      run_transition_hooks(target)
    end

    self
  end

  private

  def run_transition_hooks(target)
    self.class.transition_hooks[target].each { |hook| instance_exec(&hook) }
  end
end
