# frozen_string_literal: true

module PrometheusExporterExt
  class BaseProcessor
    class << self
      attr_accessor :logger, :type, :_on_exception

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
      end
    end

    # @param labels [Hash] default empty hash
    def initialize(labels = {})
      @metric_labels = labels || {}
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
