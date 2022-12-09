# frozen_string_literal: true

require 'prometheus_exporter'
require 'prometheus_exporter/client'
require_relative 'prometheus_exporter_ext/version'
require_relative 'prometheus_exporter_ext/configuration'
require_relative 'prometheus_exporter_ext/base_processor'
require_relative 'prometheus_exporter_ext/inline_processor'
require_relative 'prometheus_exporter_ext/periodic_processor'

module PrometheusExporterExt
  module_function

  def config
    @config ||= Configuration.new
  end

  # Configure on client side
  # @example
  #   PrometheusExporterExt.configure do |config|
  #     config.logger = Rails.logger
  #     config.enabled = Rails.configuration.my_config[:enabled]
  #     config.host = Rails.configuration.my_config[:host]
  #     config.port = Rails.configuration.my_config[:port]
  #     config.default_labels = Rails.configuration.my_config[:default_labels] || {}
  #     config.on_exception do |error, processor_class|
  #       Sentry.capture_exception(
  #         error,
  #         tags: { component: 'Prometheus', processor_class: processor_class.to_s }
  #       )
  #     end
  #   end
  def configure
    yield config

    PrometheusExporter::Client.default = config.build_client
  end

  def enabled?
    config.enabled?
  end
end
