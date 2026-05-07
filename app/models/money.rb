class Money
  include Comparable

  attr_reader :cents, :currency

  def initialize(cents, currency = "USD")
    @cents = cents.to_i
    @currency = currency
  end

  def +(other)
    raise ArgumentError, "currency mismatch" unless currency == other.currency
    self.class.new(cents + other.cents, currency)
  end

  def *(multiplier)
    self.class.new(cents * multiplier.to_i, currency)
  end

  def <=>(other)
    return nil unless other.is_a?(Money) && other.currency == currency
    cents <=> other.cents
  end

  def zero?
    cents.zero?
  end

  def format
    sign = cents.negative? ? "-" : ""
    abs_cents = cents.abs
    dollars = abs_cents / 100
    remainder = (abs_cents % 100).to_s.rjust(2, "0")
    symbol = currency == "USD" ? "$" : "#{currency} "
    "#{sign}#{symbol}#{dollars}.#{remainder}"
  end
  alias to_s format

  def self.zero(currency = "USD")
    new(0, currency)
  end
end
