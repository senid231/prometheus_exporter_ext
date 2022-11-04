# frozen_string_literal: true

require_relative 'base_processor'

module PrometheusExporterExt
  # Processor that sends metrics to prometheus exporter with given frequency.
  class PeriodicProcessor < BaseProcessor
    class << self
      attr_accessor :_after_thread_start

      # @yield
      def after_thread_start(&block)
        _after_thread_start << block
      end

      def run_after_thread_start
        _after_thread_start.each(&:call)
      end

      # @param client [PrometheusExporter::Client,nil] default PrometheusExporter::Client.default
      # @param frequency [Integer] default 30
      # @param labels [Hash] default empty hash
      def start(client: nil, frequency: 30, labels: {})
        raise ArgumentError, "#{name} already started" if running?

        client ||= PrometheusExporter::Client.default
        process_collector = new(labels.dup)

        @thread = Thread.new do
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
        subclass._after_thread_start = _after_thread_start&.dup || []
      end
    end
  end
end
