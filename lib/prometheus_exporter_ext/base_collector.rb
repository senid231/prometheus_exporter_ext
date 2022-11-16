# frozen_string_literal: true

require 'prometheus_exporter/metric'
require 'prometheus_exporter/server/type_collector'

module PrometheusExporterExt
  # Collector that caches all received data forever.
  # @example
  #   class MyCollector < PrometheusExporterExt::BaseCollector
  #     self.type = 'my'
  #
  #     define_metric_counter :my_counter, 'my_counter desc'
  #     define_metric_gauge :my_gauge, 'my_gauge desc'
  #     define_metric_histogram :my_histogram_1, 'my_histogram_1 desc'
  #     define_metric_histogram :my_histogram_2, 'my_histogram_2 desc', buckets: [0.01, 0.1, 0.5, 1, 10.0]
  #     define_metric_summary :my_summary_1, 'my_summary_1 desc'
  #     define_metric_summary :my_summary_2, 'my_summary_2 desc', quantiles: [0.99, 0.9, 0.5, 0.1, 0.01]
  #  end
  class BaseCollector < PrometheusExporter::Server::TypeCollector
    class << self
      attr_accessor :type, :_metrics, :_abstract

      # Defines counter metric.
      # @param name [Symbol,String]
      # @param help [String]
      # @example
      #   define_metric_counter :test, 'test metric'
      def define_metric_counter(name, help)
        define_metric PrometheusExporter::Metric::Counter, name, help
      end

      # Defines gauge metric.
      # @param name [Symbol,String]
      # @param help [String]
      # @example
      #   define_metric_gauge :test, 'test metric'
      def define_metric_gauge(name, help)
        define_metric PrometheusExporter::Metric::Gauge, name, help
      end

      # Defines histogram metric.
      # @param name [Symbol,String]
      # @param help [String]
      # @param opts [Hash] default empty hash
      # @example
      #   define_metric_histogram :test, 'test metric', buckets: [0.01, 0.1, 0.5, 1, 10.0]
      def define_metric_histogram(name, help, opts = {})
        define_metric PrometheusExporter::Metric::Histogram, name, help, args: [opts]
      end

      # Defines summary metric.
      # @param name [Symbol,String]
      # @param help [String]
      # @param opts [Hash] default empty hash
      # @example
      #   define_metric_summary :test, 'test metric', quantiles: [0.99, 0.9, 0.5, 0.1, 0.01]
      def define_metric_summary(name, help, opts = {})
        define_metric PrometheusExporter::Metric::Summary, name, help, args: [opts]
      end

      # Defines metric.
      # @param metric_class [Class<PrometheusExporter::Metric::Base>]
      # @param name [Symbol,String]
      # @param help [String]
      # @param args [Array] default empty array
      def define_metric(metric_class, name, help, args: [])
        name = name.to_sym
        raise ArgumentError, "metric #{name} already defined" if _metrics.key?(name)

        _metrics[name] = { metric_class: metric_class, help: help, args: args }
      end

      def abstract_class
        self._abstract = true
      end

      private

      def inherited(subclass)
        super
        subclass.type = nil
        subclass._metrics = _metrics.dup || {}
        subclass._abstract = false
      end
    end

    self._metrics = {}
    abstract_class

    def initialize
      @observers = build_observers
      super
    end

    # @return [Array<PrometheusExporter::Metric::Base>]
    def metrics
      observers.values
    end

    # @param obj [Hash<String>]
    def collect(obj)
      observe_object(obj)
      nil
    end

    # @return [String]
    def type
      self.class.type
    end

    private

    attr_reader :observers

    # @param obj [Hash<String>]
    # @return [Hash<String,PrometheusExporter::Metric::Base>]
    def observe_object(obj)
      changed_observers = {}
      labels = build_labels(obj)

      observers.each do |name, observer|
        name = name.to_s
        value = obj[name]
        if value
          observer.observe(value, labels)
          changed_observers[name] = observer
        end
      end

      changed_observers
    end

    # @param obj [Hash<String>]
    # @return [Hash]
    def build_labels(obj)
      labels = {}
      # labels are passed by processor
      labels.merge!(obj['metric_labels']) if obj['metric_labels']
      # custom_labels are passed by PrometheusExporter::Client
      labels.merge!(obj['custom_labels']) if obj['custom_labels']
      labels
    end

    # @return [Hash<Symbol,PrometheusExporter::Metric::Base>]
    def build_observers
      self.class._metrics.each_with_object({}) do |(name, opts), store|
        store[name] = opts[:metric_class].new("#{type}_#{name}", opts[:help], *opts[:args])
      end
    end

    def abstract?
      self.class._abstract
    end
  end
end
