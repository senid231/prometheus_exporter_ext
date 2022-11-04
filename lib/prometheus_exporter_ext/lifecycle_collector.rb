# frozen_string_literal: true

require_relative 'base_collector'

module PrometheusExporterExt
  # Collector that caches all received data for some time.
  # @example
  #   class MyCollector < PrometheusExporterExt::LifecycleCollector
  #     # When main prometheus process fetch metrics via GET /metrics
  #     # we clear metrics that was added earlier than 20 seconds ago.
  #     # When value is nil we clear do not clear metrics on this step.
  #     # Normally this value should be little less than prometheus polling interval.
  #     # Use it when some metrics can stop coming from the client
  #     # and you want to remove them from main prometheus process.
  #     self.clear_expired_before_return_metrics = 30
  #
  #     # When prometheus exporter receives new metrics from the client via POST /send-metrics
  #     # we clear metrics that was added earlier than 40 seconds ago.
  #     # When value is nil we clear do not clear metrics on this step.
  #     # Normally this value should be little less than client send interval.
  #     # Use it when you need to clear all old metrics when new metrics received.
  #     # In most cases it is used with PrometheusExporterExt::PeriodicProcessor on client side.
  #     self.clear_expired_when_new_metrics_received = 40
  #
  #     define_metric_counter :my_counter, 'my_counter desc'
  #     define_metric_gauge :my_gauge, 'my_counter desc'
  #     define_metric_histogram :my_histogram_1, 'my_histogram_1 desc'
  #     define_metric_histogram :my_histogram_2, 'my_histogram_2 desc', buckets: [0.01, 0.1, 0.5, 1, 10.0]
  #     define_metric_summary :my_summary_1, 'my_summary_1 desc'
  #     define_metric_summary :my_summary_2, 'my_summary_2 desc', quantiles: [0.99, 0.9, 0.5, 0.1, 0.01]
  #  end
  class LifecycleCollector < BaseCollector
    class << self
      attr_accessor :clear_expired_before_return_metrics,
                    :clear_expired_when_new_metrics_received
    end

    def initialize
      @data = []
      super
    end

    def metrics
      clear_expired_data(clear_expired_before_return_metrics)
      return [] if @data.empty?

      @observers.each_value(&:reset!)
      changed_observers = {}

      @data.each do |obj|
        changed_observers.merge observe_object(obj)
      end

      changed_observers.values
    end

    def collect(obj)
      clear_expired_data(clear_expired_when_new_metrics_received)
      obj['created_at'] = monotonic_now
      @data << obj
    end

    private

    # @param max_metric_age [Integer] seconds qty
    def clear_expired_data(max_metric_age)
      return if max_metric_age.nil?

      now = monotonic_now
      @data.delete_if { |m| m['created_at'] + max_metric_age < now }
    end

    def monotonic_now
      ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
    end

    def clear_expired_before_return_metrics
      self.class.clear_expired_before_return_metrics
    end

    def clear_expired_when_new_metrics_received?
      self.class.clear_expired_when_new_metrics_received
    end
  end
end
