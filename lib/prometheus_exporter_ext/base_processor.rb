# frozen_string_literal: true

module PrometheusExporterExt
  # Base processor class.
  # Use it when ancestors are not flexible enough for your needs.
  # @example
  #   class MyProcessor < PrometheusExporterExt::BaseProcessor
  #     self.type = 'my'
  #     self.logger = Rails.logger
  #     self.default_labels = { foo: 'bar' }
  #
  #     def collect
  #       data = MyApi.get_my_data
  #       [
  #         format_metric(
  #           my_gauge: data[:total_count],
  #           my_counter: 1,
  #           labels: { my_node: data[:node_name] }
  #         )
  #       ]
  #     end
  #   end
  #
  #   MyProcessor.new.collect.each do |metric|
  #     PrometheusExporter::Client.default.send_json(metric)
  #   end
  class BaseProcessor
    class << self
      attr_accessor :logger,
                    :type,
                    :_on_exception,
                    :default_labels

      # @yield
      # @yieldparam exception [Exception]
      def on_exception(&block)
        _on_exception << block
      end

      private

      # @param exception [Exception]
      def run_on_exception(exception)
        _on_exception.each { |cb| cb.call(exception) }
      end

      def inherited(subclass)
        super
        subclass.type = nil
        subclass._on_exception = _on_exception&.dup || []
        subclass.default_labels = default_labels&.dup || {}
      end
    end

    # @param labels [Hash] default empty hash
    def initialize(labels = {})
      @metric_labels = default_labels.merge(labels || {})
    end

    # @return [Array<Hash>] array of object returned by #format_metric
    def collect
      raise NotImplementedError
    end

    # @return [String]
    def type
      self.class.type
    end

    # @return [Logger,nil]
    def logger
      self.class.logger
    end

    private

    # @param data [Hash<Symbol>]
    # @return [Hash<Symbol>]
    def format_metric(data)
      labels = (data.delete(:labels) || {}).merge(@metric_labels)
      {
        type: type,
        metric_labels: labels,
        **data
      }
    end
  end
end
