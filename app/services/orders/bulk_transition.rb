module Orders
  class BulkTransition
    Result = Struct.new(:succeeded, :failed, keyword_init: true) do
      def total = succeeded.size + failed.size
      def succeeded? = failed.empty? && succeeded.any?
      def partial? = succeeded.any? && failed.any?

      def summary
        parts = []
        parts << "#{succeeded.size} order#{'s' if succeeded.size != 1} updated" if succeeded.any?
        if failed.any?
          parts << "#{failed.size} skipped"
        end
        parts.join(", ")
      end

      def failure_details
        failed.map { |order, message| "##{order.reference}: #{message}" }
      end
    end

    def initialize(orders:, target_state:, actor:)
      @orders = orders
      @target_state = target_state.to_sym
      @actor = actor
    end

    def call
      succeeded = []
      failed = []

      @orders.each do |order|
        begin
          order.transition_to!(@target_state, actor: @actor, metadata: { source: "bulk" })
          succeeded << order
        rescue OrderStateMachine::InvalidTransition => e
          failed << [ order, e.message ]
        rescue ActiveRecord::RecordInvalid => e
          failed << [ order, e.message ]
        end
      end

      Result.new(succeeded: succeeded, failed: failed)
    end
  end
end
