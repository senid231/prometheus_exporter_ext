# frozen_string_literal: true

module PrometheusExporterExt
  # Processor format input data and send metrics on call.
  # Use when you need to send metrics as result of some action.
  # @example
  #   class MyProcessor < PrometheusExporterExt::InlineProcessor
  #     self.type = 'my'
  #     self.logger = Rails.logger
  #     self.default_labels = { foo: 'bar' }
  #
  #     def collect(data)
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
  #   data = MyApi.get_my_data
  #   MyProcessor.process(data, labels: { my_host: 'example.com' })
  class InlineProcessor < BaseProcessor
    class << self
      # @param args [Array]
      # @param labels [Hash]
      # @param client [PrometheusExporter::Client,nil] default PrometheusExporter::Client.default
      def process(*args, labels: {}, client: nil)
        processor = new(labels)
        metrics = processor.collect(*args)
        client ||= PrometheusExporter::Client.default

        Thread.new do
          metrics.each { |metric| client.send_json(metric) }
        rescue StandardError => e
          warn "#{self.class} Failed To Collect Stats #{e.class} #{e.message}"
          logger&.error { "#{e.class} #{e.message} #{e.backtrace&.join("\n")}" }
          handle_exception(e)
        end
      end
    end

    def collect(*args)
      raise NotImplementedError
    end
  end
end
