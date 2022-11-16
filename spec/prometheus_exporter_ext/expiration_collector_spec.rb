# frozen_string_literal: true

require 'prometheus_exporter_ext/expiration_collector'

RSpec.describe PrometheusExporterExt::ExpirationCollector do
  let(:collector_class) do
    Class.new(described_class) do
      self.type = 'rspec_test'
      self.max_metric_age = 2
      define_metric_gauge :foo, 'test'
    end
  end
  let(:collector) { collector_class.new }

  describe '#collect' do
    subject do
      collector.collect(
        prepare_metric_object(data)
      )
    end

    let(:data) do
      {
        type: collector_class.type,
        foo: 1
      }
    end

    it 'adds metrics' do
      subject
      expect(collector.metrics).to have_metric_text(
                                     'rspec_test_foo 1'
                                   )
    end

    context 'when metric with same labels already collected' do
      before do
        old_data = {
          type: collector_class.type,
          foo: 123
        }
        collector.collect prepare_metric_object(old_data)
      end

      it 'replaces metrics' do
        subject
        expect(collector.metrics).to have_metric_text(
                                       'rspec_test_foo 1'
                                     )
      end
    end

    context 'when metric with different labels already collected' do
      before do
        old_data = {
          type: collector_class.type,
          foo: 123,
          metric_labels: { a: 'b' }
        }
        collector.collect prepare_metric_object(old_data)
      end

      it 'replaces metrics' do
        subject
        expect(collector.metrics).to have_metric_text(
                                       'rspec_test_foo{a="b"} 123',
                                       'rspec_test_foo 1'
                                     )
      end
    end

    context 'with metric_labels' do
      let(:data) do
        {
          type: collector_class.type,
          foo: 2,
          metric_labels: { a: 'b' }
        }
      end

      it 'adds metrics' do
        subject
        expect(collector.metrics).to have_metric_text(
                                       'rspec_test_foo{a="b"} 2'
                                     )
      end
    end

    context 'with custom_labels' do
      let(:data) do
        {
          type: collector_class.type,
          foo: 3,
          custom_labels: { a: 'b' }
        }
      end

      it 'adds metrics' do
        subject
        expect(collector.metrics).to have_metric_text(
                                       'rspec_test_foo{a="b"} 3'
                                     )
      end
    end

    context 'with both metric_labels and custom_labels' do
      let(:data) do
        {
          type: collector_class.type,
          foo: 4,
          metric_labels: { a: 'b' },
          custom_labels: { c: 'd' }
        }
      end

      it 'adds metrics' do
        subject
        expect(collector.metrics).to have_metric_text(
                                       'rspec_test_foo{a="b",c="d"} 4'
                                     )
      end
    end
  end

  describe '#metrics' do
    subject do
      collector.metrics
    end

    it 'returns no metrics' do
      expect(subject).not_to have_metric_text
    end

    context 'when metric collected just now' do
      before do
        data = {
          type: collector_class.type,
          foo: 123,
          metric_labels: { a: 'b' },
          custom_labels: { test: 'qwe' }
        }
        collector.collect prepare_metric_object(data)
      end

      it 'returns metrics' do
        expect(subject).to have_metric_text(
                             'rspec_test_foo{a="b",test="qwe"} 123'
                           )
      end
    end

    context 'when metric was collected less than :max_metric_age seconds ago' do
      before do
        data = {
          type: collector_class.type,
          foo: 123,
          metric_labels: { a: 'b' },
          custom_labels: { test: 'qwe' }
        }
        raw_data = prepare_metric_object(data)
        collector.collect(raw_data)
        sleep 1.9
      end

      it 'returns metrics' do
        expect(subject).to have_metric_text(
                             'rspec_test_foo{a="b",test="qwe"} 123'
                           )
      end
    end

    context 'when metric was collected more than :max_metric_age seconds ago' do
      before do
        data = {
          type: collector_class.type,
          foo: 123,
          metric_labels: { a: 'b' },
          custom_labels: { test: 'qwe' }
        }
        raw_data = prepare_metric_object(data)
        collector.collect(raw_data)
        sleep 2.01
      end

      it 'returns no metrics' do
        expect(subject).not_to have_metric_text
      end
    end

    context 'when expired and not expired metrics was collected' do
      before do
        data = {
          type: collector_class.type,
          foo: 123,
          metric_labels: { a: 'b' },
          custom_labels: { test: 'qwe' }
        }
        collector.collect prepare_metric_object(data)
        sleep 2.01

        data2 = {
          type: collector_class.type,
          foo: 124,
          metric_labels: { b: 'c' }
        }
        collector.collect prepare_metric_object(data2)
      end

      it 'returns metrics' do
        expect(subject).to have_metric_text(
                             'rspec_test_foo{b="c"} 124'
                           )
      end
    end

    context 'when 2 metrics was collected just now' do
      before do
        data = {
          type: collector_class.type,
          foo: 123,
          metric_labels: { a: 'b' }
        }
        collector.collect prepare_metric_object(data)
        data2 = {
          type: collector_class.type,
          foo: 124,
          metric_labels: { b: 'c' }
        }
        collector.collect prepare_metric_object(data2)
      end

      it 'returns metrics' do
        expect(subject).to have_metric_text(
                             'rspec_test_foo{a="b"} 123',
                             'rspec_test_foo{b="c"} 124'
                           )
      end
    end
  end
end
