# frozen_string_literal: true

require_relative 'base_collector'

module PrometheusExporterExt
  # Collector that caches all received data for defined interval
  # and gives main prometheus process only not expired metrics.
  # When main prometheus process fetch metrics via GET /metrics
  # we clear metrics that was added earlier than :max_metric_age seconds ago.
  # Use it when some metrics can stop coming from the client
  # and you want to remove them from main prometheus process.
  # In most cases it is used with PrometheusExporterExt::PeriodicProcessor on client side.
  # @example
  #   class MyCollector < PrometheusExporterExt::ExpirationCollector
  #     self.type = 'my'
  #
  #     # By default value is 35.
  #     # Normally this value should be little greater than client send frequency,
  #     # so old data will be cleared after new one received.
  #     self.max_metric_age = 35
  #
  #     define_metric_gauge :my_gauge, 'my_gauge desc'
  #   end
  class ExpirationCollector < BaseCollector
    class << self
      attr_accessor :max_metric_age

      private

      def inherited(subclass)
        super
        subclass.max_metric_age = max_metric_age || 35
      end
    end

    abstract_class

    def initialize
      raise ArgumentError, 'max_metric_age must be an integer' if !abstract? && !max_metric_age.is_a?(Integer)

      @data = []
      super
    end

    def metrics
      clear_expired_data
      return [] if @data.empty?

      @observers.each_value(&:reset!)
      changed_observers = {}

      @data.each do |obj|
        changed_observers.merge! observe_object(obj)
      end

      changed_observers.values
    end

    def collect(obj)
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
