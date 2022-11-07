# frozen_string_literal: true

module PrometheusExporterExt
  class Configuration
    attr_accessor :enabled,
                  :host,
                  :port,
                  :default_labels

    alias enabled? enabled

    def initialize
      @enabled = false
      @host = PrometheusExporter::DEFAULT_BIND_ADDRESS
      @port = PrometheusExporter::DEFAULT_PORT
      @default_labels = {}
      @on_exception = []
    end

    # @return [PrometheusExporter::Client]
    def build_client
      return unless enabled

      require 'prometheus_exporter/client'

      PrometheusExporter::Client.new(
        host: host,
        port: port,
        custom_labels: default_labels
      )
    end

    # @yield
    # @yieldparam exception [Exception]
    # @yieldparam processor_class [Class]
    def on_exception(&block)
      @on_exception << block
    end

    # @param exception [Exception]
    def handle_exception(exception, processor_class)
      @on_exception.each { |cb| cb.call(exception, processor_class) }
    end
  end
end
