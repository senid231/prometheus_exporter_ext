# frozen_string_literal: true

require 'json'

module PrometheusExporterExt
  module RSpecHelper
    # emulate object received from json request
    def prepare_metric_object(obj)
      JSON.parse JSON.generate(obj)
    end
  end
end

RSpec.configure do |config|
  config.include PrometheusExporterExt::RSpecHelper
end

RSpec::Matchers.define :have_metric_text do |*expected|
  match do |actual|
    @actual_array = actual_to_text_array(actual)
    expected_array = match_array(expected)
    values_match? expected_array, @actual_array
  end

  match_when_negated do |actual|
    @actual_array = actual_to_text_array(actual)
    values_match? [], @actual_array
  end

  def actual_to_text_array(actual)
    actual.map(&:metric_text).flat_map { |text| text.split("\n") }.reject(&:empty?)
  end

  failure_message do |_actual|
    expected_formatted = RSpec::Support::ObjectFormatter.format(expected)
    actual_formatted = RSpec::Support::ObjectFormatter.format(@actual_array)
    "expected metrics #{actual_formatted}\nto match:\n#{expected_formatted}"
  end
end
