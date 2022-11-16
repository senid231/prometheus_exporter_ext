# frozen_string_literal: true

RSpec.describe PrometheusExporterExt do
  after do
    PrometheusExporter::Client.default = nil
    described_class.instance_variable_set(:@config, nil)
  end

  describe '.config' do
    subject do
      described_class.config
    end

    it 'returns cached config' do
      expect(subject).to be_a(PrometheusExporterExt::Configuration)
      expect(subject.object_id).to eq described_class.config.object_id
    end
  end

  describe '.configure' do
    subject do
      described_class.configure do |config|
        config.enabled = enabled
        config.host = '1.2.3.4'
        config.port = 7879
        config.default_labels = { foo: 'bar' }
      end
    end

    let(:enabled) { true }

    it 'yields config' do
      expect { |b| described_class.configure(&b) }.to yield_with_args(described_class.config)
    end

    it 'assigns config properties' do
      subject

      expect(described_class.config.enabled).to be true
      expect(described_class.config.host).to eq '1.2.3.4'
      expect(described_class.config.port).to eq 7879
      expect(described_class.config.default_labels).to eq(foo: 'bar')
    end

    it 'configures PrometheusExporter::Client.default' do
      expect { subject }.to change {
        PrometheusExporter::Client.default.object_id
      }

      default_client = PrometheusExporter::Client.default
      expect(default_client).to be_a PrometheusExporter::Client
      expect(default_client.instance_variable_get(:@host)).to eq described_class.config.host
      expect(default_client.instance_variable_get(:@port)).to eq described_class.config.port
      expect(default_client.instance_variable_get(:@custom_labels)).to eq described_class.config.default_labels
    end

    context 'when enabled is false' do
      let(:enabled) { false }

      it 'assigns config properties' do
        subject

        expect(described_class.config.enabled).to be false
        expect(described_class.config.host).to eq '1.2.3.4'
        expect(described_class.config.port).to eq 7879
        expect(described_class.config.default_labels).to eq(foo: 'bar')
      end
    end

    context 'with default config' do
      it 'assigns config properties' do
        described_class.configure { nil }

        expect(described_class.config.enabled).to be true
        expect(described_class.config.host).to eq 'localhost'
        expect(described_class.config.port).to eq 9394
        expect(described_class.config.default_labels).to eq({})
      end

      it 'configures PrometheusExporter::Client.default' do
        described_class.configure { nil }

        default_client = PrometheusExporter::Client.default
        expect(default_client).to be_a PrometheusExporter::Client
        expect(default_client.instance_variable_get(:@host)).to eq described_class.config.host
        expect(default_client.instance_variable_get(:@port)).to eq described_class.config.port
        expect(default_client.instance_variable_get(:@custom_labels)).to eq described_class.config.default_labels
      end
    end
  end

  describe '.enabled?' do
    subject do
      described_class.enabled?
    end

    it { is_expected.to be true }

    context 'when config.enabled=false' do
      before do
        described_class.configure { |config| config.enabled = false }
      end

      it { is_expected.to be false }
    end
  end
end
