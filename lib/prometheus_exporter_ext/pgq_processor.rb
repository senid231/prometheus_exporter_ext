# frozen_string_literal: true

require 'prometheus_exporter/client'
require_relative 'sql_caller/active_record'

module PrometheusExporterExt
  # @example
  #   require 'prometheus_exporter_ext/pgq_processor'
  #
  #   module Prometheus
  #     class PgqProcessor < ::PrometheusExporterExt::PgqProcessor
  #       self.type = 'billing_pgq'
  #       model_class 'ApplicationRecord'
  #
  #       gather_queue_data(:new_events) { |queue_info| queue_info[:ev_new] }
  #       gather_queue_data(:ev_per_sec) { |queue_info| queue_info[:ev_per_sec] || 0.0 }
  #       gather_consumer_data(:pending_events) { |consumer_info, _| consumer_info[:pending_events] }
  #     end
  # end
  class PgqProcessor < PeriodicProcessor
    class << self
      attr_accessor :sql_caller, :metric_opts

      def model_class(class_name)
        self.sql_caller = PrometheusExporterExt::SqlCaller::ActiveRecord.new(class_name)
      end

      def gather_queue_data(name, labels: {}, &block)
        gather_data(name, from: :queue, labels: labels, &block)
      end

      def gather_consumer_data(name, labels: {}, &block)
        gather_data(name, from: :consumer, labels: labels, &block)
      end

      def gather_custom_data(name, labels: {}, &block)
        gather_data(name, from: nil, labels: labels, &block)
      end

      def gather_data(name, from:, labels: {}, &block)
        name = name.to_sym
        raise ArgumentError, "metric #{name} already defined" if metric_opts.key?(name)

        metric_opts[name] = { from: from, labels: labels, apply: block }
      end

      private

      def inherited(subclass)
        super
        subclass.metric_opts = metric_opts&.dup || {}
      end
    end

    self.metric_opts = {}

    after_thread_start do
      sql_caller.release_connection
    end

    def collect
      metrics = []
      sql_caller.with_connection do
        sql_caller.queue_info.each do |queue_info|
          queue = queue_info[:queue_name]

          queue_metric_opts.each do |name, opts|
            value = opts[:apply].call(queue_info)
            labels = opts[:labels].merge(queue: queue)
            metrics << format_metric(name => value, labels: labels)
          end

          sql_caller.consumer_info(queue).each do |consumer_info|
            consumer = consumer_info[:consumer_name]

            consumer_metric_opts.each do |name, opts|
              value = opts[:apply].call(consumer_info, queue_info)
              labels = opts[:labels].merge(queue: queue, consumer: consumer)
              metrics << format_metric(name => value, labels: labels)
            end
          end
        end

        custom_metric_opts.each do |name, opts|
          value, value_labels = opts[:apply].call
          labels = opts[:labels].merge(value_labels || {})
          metrics << format_metric(name => value, labels: labels)
        end
      end

      metrics
    end

    private

    def sql_caller
      self.class.sql_caller
    end

    def queue_metric_opts
      self.class.metric_opts.select { |_, opts| opts[:from] == :queue }
    end

    def consumer_metric_opts
      self.class.metric_opts.select { |_, opts| opts[:from] == :consumer }
    end

    def custom_metric_opts
      self.class.metric_opts.select { |_, opts| opts[:from].nil? }
    end
  end
end
