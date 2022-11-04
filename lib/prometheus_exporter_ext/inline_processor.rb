# frozen_string_literal: true

require_relative 'base_processor'

module PrometheusExporterExt
  class InlineProcessor < BaseProcessor
    class << self
      # @param data
      # @param labels [Hash]
      # @param client [PrometheusExporter::Client,nil] default PrometheusExporter::Client.default
      def process(data, labels: {}, client: nil)
        metrics = new(labels).collect(data)
        client ||= PrometheusExporter::Client.default

        Thread.new do
          metrics.each { |metric| client.send_json(metric) }
        rescue StandardError => e
          warn "#{self.class} Failed To Collect Stats #{e.class} #{e.message}"
          logger&.error { "#{e.class} #{e.message} #{e.backtrace&.join("\n")}" }
          run_on_exception(e)
        end
      end
    end

    # @param data
    def collect(data)
      raise NotImplementedError
    end
  end
end
