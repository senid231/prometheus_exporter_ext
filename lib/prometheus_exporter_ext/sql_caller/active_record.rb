# frozen_string_literal: true

module PrometheusExporterExt
  module SqlCaller
    # Simple Sql caller for active record.
    class ActiveRecord
      # @param model_class_name [Class<Object>,String] class or class name
      def initialize(model_class_name)
        @model_class_name = model_class_name.to_s
      end

      # Returns pgq.get_queue_info for one or all queues.
      # @param queue [String, nil] queue name
      # @return [Hash<Symbol>] when queue is present.
      # @return [Array<Hash<Symbol>>] when queue is nil.
      def queue_info(queue = nil)
        if queue
          select_hashes('SELECT * FROM pgq.get_queue_info(?)', queue.to_s).first
        else
          select_hashes('SELECT * FROM pgq.get_queue_info()')
        end
      end

      # Returns pgq.get_consumer_info for one or all consumers of queue.
      # @param queue [String] queue name
      # @param consumer [String, nil] consumer name
      # @return [Hash<Symbol>] when queue is present.
      # @return [Array<Hash<Symbol>>] when queue is nil.
      def consumer_info(queue, consumer = nil)
        if consumer
          select_hashes('SELECT * FROM pgq.get_consumer_info(?, ?)', queue.to_s, consumer.to_s).first
        else
          select_hashes('SELECT * FROM pgq.get_consumer_info(?)', queue.to_s)
        end
      end

      # Releases active pg connection in thread.
      # Do nothing if no connection captured.
      def release_connection
        model_class.connection_pool.release_connection
      end

      # Acquires pg connection during block execution.
      # Release it after block executed.
      # @yield
      def with_connection(&block)
        model_class.connection_pool.with_connection(&block)
      end

      private

      def model_class
        @model_class ||= Kernel.const_get(@model_class_name)
      end

      def select_hashes(sql, *bindings)
        sql = model_class.send :sanitize_sql_array, bindings.unshift(sql) unless bindings.empty?
        result = model_class.connection.select_all(sql)
        result.map do |row|
          row.to_h { |k, v| [k.to_sym, result.column_types[k].deserialize(v)] }
        end
      end
    end
  end
end
