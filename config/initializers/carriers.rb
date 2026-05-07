Rails.application.configure do
  config.carriers = {
    default: :fake,
    min_latency_ms: 50,
    max_latency_ms: 250,
    timeout_rate: 0.05,
    malformed_rate: 0.05
  }
end
