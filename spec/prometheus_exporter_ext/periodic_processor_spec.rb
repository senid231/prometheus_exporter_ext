# frozen_string_literal: true

RSpec.describe PrometheusExporterExt::PeriodicProcessor do
  describe '#collect' do
    subject do
      processor_instance.collect(data)
    end

    let(:processor_class) do
      Class.new(described_class) do
        self.type = 'inline_test'

        def collect(data)
          [
            format_metric(
              mt: data[:val],
              labels: { a: data[:a] }
            )
          ]
        end
      end
    end
    let(:processor_instance) { processor_class.new }
    let(:data) do
      { val: 123, a: 'qwe' }
    end

    it 'returns metric data' do
      expect(subject).to eq(
                           [
                             type: 'inline_test',
                             mt: 123,
                             metric_labels: { a: 'qwe' }
                           ]
                         )
    end

    context 'when processor instantiated with labels' do
      let(:processor_instance) { processor_class.new(foo: 'bar') }

      it 'returns metric data' do
        expect(subject).to eq(
                             [
                               type: 'inline_test',
                               mt: 123,
                               metric_labels: { foo: 'bar', a: 'qwe' }
                             ]
                           )
      end
    end
  end
end
