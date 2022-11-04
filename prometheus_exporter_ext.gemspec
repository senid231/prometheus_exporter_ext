# frozen_string_literal: true

require_relative 'lib/prometheus_exporter_ext/version'

Gem::Specification.new do |spec|
  spec.name = 'prometheus_exporter_ext'
  spec.version = PrometheusExporterExt::VERSION
  spec.authors = ['Denis Talakevich']
  spec.email = ['senid231@gmail.com']

  spec.summary = 'Prometheus Exporter extended processors and collectors'
  spec.description = spec.summary
  spec.homepage = 'https://github.com/didww/prometheus_exporter_ext'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.7.6'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|spec)/|\.(?:git|github))})
    end
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'prometheus_exporter', '~> 0.5'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
