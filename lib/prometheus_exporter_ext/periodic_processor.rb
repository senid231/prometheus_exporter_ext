# frozen_string_literal: true

require_relative 'base_processor'

module PrometheusExporterExt
  # Processor that sends metrics to prometheus exporter with given frequency.
  # Creates a thread that sends metrics periodically with given frequency, default 30.
  # Use when you need to monitor state of something.
  # Normally used with PrometheusExporterExt::ExpirationCollector
  # or PrometheusExporterExt::LifecycleCollector.
  # @example
  #   class MyProcessor < PrometheusExporterExt::PeriodicProcessor
  #     self.type = 'my'
  #     self.logger = Rails.logger
  #     self.default_frequency = 60
  #     self.default_labels = { foo: 'bar' }
  #
  #     # being run inside thread before loop starts.
  #     after_thread_start do
  #       MyConnection.disconnect
  #     end
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
  #   MyProcessor.start(labels: { my_host: 'example.com' })
  class PeriodicProcessor < BaseProcessor
    class << self
      attr_accessor :default_frequency,
                    :_after_thread_start

      # @yield
      def after_thread_start(&block)
        _after_thread_start << block
      end

      def run_after_thread_start
        _after_thread_start.each(&:call)
      end

      # @param client [PrometheusExporter::Client,nil] default PrometheusExporter::Client.default
      # @param frequency [Integer] default class property default_frequency (default 30)
      # @param labels [Hash] default empty hash
      def start(client: nil, frequency: default_frequency, labels: {})
        raise ArgumentError, "#{name} already started" if running?

        client ||= PrometheusExporter::Client.default

        @thread = Thread.new do
          process_collector = new(labels)

          within_log_tags(name) do
            run_after_thread_start
            logger&.info { "Start #{name}" }
            loop do
              begin
                metrics = process_collector.collect
                metrics.each { |metric| client.send_json(metric) }
              rescue StandardError => e
                warn "#{self.class} Failed To Collect Stats #{e.class} #{e.message}"
                logger&.error { "#{e.class} #{e.message} #{e.backtrace&.join("\n")}" }
                run_on_exception(e)
              end
              sleep frequency
            end
          end
        end

        true
      end

      def stop
        @thread&.kill
        @thread = nil
      end

      def running?
        defined?(@thread) && @thread
      end

      private

      def within_log_tags(...)
        if logger.respond_to?(:tagged)
          logger.tagged(...)
        else
          yield
        end
      end

      def inherited(subclass)
        super
        subclass.default_frequency = default_frequency || 30
        subclass._after_thread_start = _after_thread_start&.dup || []
      end
    end
  end
end
