module OrdersHelper
  def status_badge(status)
    tag.span(status.to_s.humanize, class: "badge badge-#{status}")
  end

  def filter_link_class(value, current)
    if value == current || (value.nil? && current.nil?)
      "filter-link active"
    else
      "filter-link"
    end
  end

  def action_button_style(target)
    case target.to_sym
    when :cancelled then "danger"
    when :delivered then "success"
    else "primary"
    end
  end

  def confirmation_for(target)
    case target.to_sym
    when :cancelled
      "Cancel this order? This cannot be undone."
    when :delivered
      "Mark this order as delivered?"
    else
      "Move this order to #{target}?"
    end
  end
end
