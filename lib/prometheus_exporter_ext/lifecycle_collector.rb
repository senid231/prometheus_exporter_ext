# frozen_string_literal: true

require_relative 'base_collector'

module PrometheusExporterExt
  # Collector that caches all received data for some time.
  # When prometheus exporter receives new metrics from the client via POST /send-metrics
  # we clear metrics that was added earlier than :max_metric_age seconds ago.
  # In most cases it is used with PrometheusExporterExt::PeriodicProcessor on client side.
  # @example
  #   class MyCollector < PrometheusExporterExt::LifecycleCollector
  #     self.type = 'my'
  #
  #     # By default value is 25
  #     # Normally this value should be little less than client send interval,
  #     # so when new metrics received old one will be already expired.
  #     # Use it when you need to clear all old metrics when new metrics received.
  #     self.max_metric_age = 25
  #
  #     define_metric_gauge :my_gauge, 'my_gauge desc'
  #   end
  class LifecycleCollector < BaseCollector
    class << self
      attr_accessor :max_metric_age

      private

      def inherited(subclass)
        super
        subclass.max_metric_age = max_metric_age || 25
      end
    end

    abstract_class

    def initialize
      raise ArgumentError, 'max_metric_age must be an integer' if !abstract? && !max_metric_age.is_a?(Integer)

      @data = []
      super
    end

    def metrics
      return [] if @data.empty?

      @observers.each_value(&:reset!)
      changed_observers = {}

      @data.each do |obj|
        changed_observers.merge! observe_object(obj)
      end

      changed_observers.values
    end

    def collect(obj)
      clear_expired_data
      obj['created_at'] = monotonic_now
      @data << obj
    end

    private

    def clear_expired_data
      now = monotonic_now
      @data.delete_if { |m| m['created_at'] + max_metric_age < now }
    end

    def monotonic_now
      ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
    end

    def max_metric_age
      self.class.max_metric_age
    end
  end
end
