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
  def configure
    yield config

    PrometheusExporter::Client.default = config.build_client
  end

  def enabled?
    config.enabled?
  end
end
