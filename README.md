# PrometheusExporterExt

Extended processors and collectors for [prometheus_exporter](https://github.com/discourse/prometheus_exporter).  
This gem based on prometheus_exporter gem, so please read it's `README` first to understand how it works.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add prometheus_exporter_ext

Or add directly to the Gemfile

```ruby
gem 'prometheus_exporter_ext', `~> 0.1`, require: false
```

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install prometheus_exporter_ext

## Usage

### Prometheus general information

Prometheus is system that stores metrics data as time-series, name, value, labels set.
It used to provide monitoring, charts and many more.
see [Prometheus overview](https://prometheus.io/docs/introduction/overview/) for additional details.

Prometheus Metric Types
* Gauge - new value for same name/labels replace old value.
* Counter - new value for same name/labels increments old value.
* Summary
* Histogram
see [Metric types](https://prometheus.io/docs/concepts/metric_types/) for additional details.

How prometheus Gather metrics?  
Prometheus has list of endpoints (http://host:port) and each scrapping interval (default 5 sec)
it fetches metrics for those endpoints via **GET /metrics**.
Prometheus stores received metrics with the time-series data when it was received.

What is Prometheus Exported?
It's some kind of a proxy between Prometheus and our applications.  
Instead of responding **GET /metrics** on each application, we push metrics data to the prometheus exporter.
Client should send data to the exporter in client-oriented format - Hash.
Prometheus exporter responsible to receive and convert metrics data into metrics text in prometheus format.  
Also prometheus exporter responsible to forget some metrics when it needed, 
because prometheus exporter does not handle time-series.

To gather metrics for your need we have several built-in collectors and processors that simplifies common tasks.

### Configuration

```ruby
PrometheusExporterExt.configure do |config|
  config.enabled = ENV['PROMETHEUS_ENABLED']
  config.host = ENV['PROMETHEUS_HOST']
  config.port = ENV['PROMETHEUS_PORT']
  config.default_labels = { node_name: ENV['NODE_NAME'] }

  # you can add on_exception callback to send events into error notifications system 
  on_exception do |error, processor|
    ErrorNotificationSender.capture_error(error, { processor: processor.class.name })
  end
end

if PrometheusExporterExt.enabled?
 # ...
end
```

### Processors

Processors are used to gather metrics data on client side.  
Each metrics data in the context of the client is a simple Hash with keys and values.  
Each metrics data must have a `type` key, because exporter will decide 
which collector should handle data by `type` value.

Below you can find most common types of **Processor** that covers most of the cases.

#### PrometheusExporterExt::InlineProcessor
`PrometheusExporterExt::InlineProcessor` format input data and send metrics on call.
Metrics are send in a thread.  
Use when you need to send metrics as result of some action.

```ruby
require 'prometheus_exporter_ext/inline_processor'

class MyProcessor < PrometheusExporterExt::InlineProcessor
  self.type = 'my' # required
  self.logger = Rails.logger # can be omitted
  # change default_labels when you need same labels for all calls of this processor
  self.default_labels = { a: 'b' } # can be omitted, default empty hash

  # you can add on_exception callback to send events into error notifications system 
  on_exception do |error|
    ErrorNotificationSender.capture_error(error, { processor: 'MyProcessor' })
  end

  def collect(data)
    [
      format_metric(
        my_gauge: data[:total_count],
        my_counter: 1,
        labels: { my_node: data[:node_name] }
      )
    ]
  end
end

data = MyApi.get_my_data # => { total_count: 123, node_name: 'example' }
# below command will send metrics to the prometheus exporter via PrometheusExporter::Client.default
# Collector will receive: 
# { 'type': 'my', 'my_gauge' => 123, 'my_counter' => 1, 'labels' => { 'a' => 'b', 'my_node' => 'example' } }
MyProcessor.process(data)
# You can provide additional labels that will be added only to this data.
# Collector will receive: 
# { 'type': 'my', 'my_gauge' => 123, 'my_counter' => 1, 
#   'labels' => { 'a' => 'b', 'my_node' => 'example', 'my_host' => 'example.com' } }
MyProcessor.process(data, labels: { my_host: 'example.com' })
# Also you can override client
MyProcessor.process(data, client: MyPrometheusClient.instance)
```

#### PrometheusExporterExt::PeriodicProcessor
`PrometheusExporterExt::PeriodicProcessor` sends metrics to prometheus exporter with given frequency.  
Creates a thread that sends metrics periodically with given frequency, default 30.  
Use when you need to monitor state of something.  
Normally used with `PrometheusExporterExt::ExpirationCollector` or `PrometheusExporterExt::LifecycleCollector`.
```ruby
require 'prometheus_exporter_ext/periodic_processor'

class MyProcessor < PrometheusExporterExt::PeriodicProcessor
  self.type = 'my' # required
  self.logger = Rails.logger # can be omitted
  # change default_frequency when you need different interval for all instances of this processor
  self.default_frequency = 60 # can be omitted, default 30
  # change default_labels when you need same labels for all instances of this processor
  self.default_labels = { a: 'b' } # can be omitted, default empty hash

  # you can add on_exception callback to send events into error notifications system.
  after_thread_start do
    MyDB.disconnect
  end

  # will be called when metrics sending raises exception
  on_exception do |error|
    ErrorNotificationSender.capture_error(error, { processor: 'MyProcessor' })
  end

  def collect
    MyDB.with_connection do |conn|
      data = conn.get_my_data # => { total_count: 123, node_name: 'example' }
      [
        format_metric(
          my_gauge: data[:total_count],
          my_counter: 1,
          labels: { my_node: data[:node_name] }
        )
      ]
    end
  end
end

# Collector will receive following each `MyProcessor.default_frequency` seconds: 
# { 'type': 'my', 'my_gauge' => 123, 'my_counter' => 1, 'labels' => { 'a' => 'b', 'my_node' => 'example' } }
MyProcessor.start
# You can change send frequency for the processor if you need it different in different processes,
# but most common approach is to change `MyProcessor.default_frequency` instead.
MyProcessor.start(frequency: 60)
# Also you can provide additional labels that will be send with all metrics data.
# Collector will receive: 
# { 'type': 'my', 'my_gauge' => 123, 'my_counter' => 1, 
#   'labels' => { 'a' => 'b', 'my_node' => 'example', 'my_host' => 'example.com' } }
MyProcessor.start(labels: { my_host: 'example.com' })
```

#### PrometheusExporterExt::BaseProcessor
When you need some custom processor behaviour that does not feet any of above examples
you can inherit `PrometheusExporterExt::BaseProcessor`.
```ruby
require 'prometheus_exporter_ext/base_processor'

class MyProcessor < PrometheusExporterExt::BaseProcessor
  self.type = 'my'
  # change default_labels when you need same labels for all instances of this processor
  self.default_labels = { a: 'b' } # can be omitted, default empty hash
  
  def collect
    data = MyApi.get_my_data # => { total_count: 123, node_name: 'example' }
    [
      format_metric(
        my_gauge: data[:total_count],
        my_counter: 1,
        labels: { my_node: data[:node_name] }
      )
    ]
  end
end

# Gather metrics data by calling #collect method
# [{ 'type': 'my', 'my_gauge' => 123, 'my_counter' => 1, 'labels' => { 'a' => 'b', 'my_node' => 'example' } }]
metrics_data = MyProcessor.new.collect
# Also you can pass additional labels to the collector
# [{ 'type': 'my', 'my_gauge' => 123, 'my_counter' => 1,
#    'labels' => { 'a' => 'b', 'baz' => 'boo', 'my_node' => 'example' } }]
metrics_data = MyProcessor.new(baz: 'boo').collect
# And send metrics data like this:
metrics_data.each do |metric|
  PrometheusExporter::Client.default.send_json(metric)
end
```

### Collectors

On boot exporter create and store collector instances of each class that we define.
Collectors instance receive metrics data that have same `type` value.

Below you can see common use cases of the collector.

#### PrometheusExporterExt::BaseCollector
`PrometheusExporterExt::BaseCollector` caches all received data during exporter process is running.
It will store keys that are registered via `define_metric_*` methods with provided `metric_labels`, and ignore extra keys.

```ruby
require 'prometheus_exporter_ext/base_collector'

class MyCollector < PrometheusExporterExt::BaseCollector
  self.type = 'my'
  
  define_metric_counter :my_counter, 'my_counter desc'
  define_metric_gauge :my_gauge, 'my_gauge desc'
  define_metric_histogram :my_histogram_1, 'my_histogram_1 desc'
  define_metric_histogram :my_histogram_2, 'my_histogram_2 desc', buckets: [0.01, 0.1, 0.5, 1, 10.0]
  define_metric_summary :my_summary_1, 'my_summary_1 desc'
  define_metric_summary :my_summary_2, 'my_summary_2 desc', quantiles: [0.99, 0.9, 0.5, 0.1, 0.01]
end
```

#### PrometheusExporterExt::ExpirationCollector
`PrometheusExporterExt::ExpirationCollector` that caches all received data for defined interval
and gives main prometheus process only not expired metrics.  
When main prometheus process fetch metrics via GET /metrics
we clear metrics that was added earlier than `:max_metric_age` seconds ago.  
Use it when some metrics can stop coming from the client
and you want to remove them from main prometheus process.  
In most cases it is used with `PrometheusExporterExt::PeriodicProcessor` on client side.

```ruby
require 'prometheus_exporter_ext/expiration_collector'

class MyCollector < PrometheusExporterExt::ExpirationCollector
  self.type = 'my'
  
  # By default value is 35.
  # Normally this value should be little greater than client send frequency,
  # so old data will be cleared after new one received.
  self.max_metric_age = 35
  
  define_metric_gauge :my_gauge, 'my_gauge desc'
end
```

#### PrometheusExporterExt::LifecycleCollector
`PrometheusExporterExt::LifecycleCollector` that caches all received data for some time.  
When prometheus exporter receives new metrics from the client via `POST /send-metrics`
we clear metrics that was added earlier than `:max_metric_age` seconds ago.  
In most cases it is used with `PrometheusExporterExt::PeriodicProcessor` on client side.

```ruby
require 'prometheus_exporter_ext/lifecycle_collector'

class MyCollector < PrometheusExporterExt::LifecycleCollector
  self.type = 'my'
  
  # By default value is 25
  # Normally this value should be little less than client send interval,
  # so when new metrics received old one will be already expired.
  # Use it when you need to clear all old metrics when new metrics received.
  self.max_metric_age = 25
  
  define_metric_gauge :my_gauge, 'my_gauge desc'
end
```

## How to configure prometheus exporter client side on Rails

For example we want to use `AppOnlineProcessor` on puma master to monitor whether application online or not.  
And want to monitor `AppRamProcessor` on both puma master and it's workers.
Also we have service `SomeService` that we want to monitor about errors, 
every exception there should increment counter in `SomeServiceErrorProcessor`

1. Place you processors into `lib/prometheus/`  
`lib/prometheus/app_online_processor`
```ruby
module Prometheus
  class AppOnlineProcessor < PrometheusExporterExt::PeriodicProcessor
    self.type = 'app_online'
    self.logger = Rails.logger
    self.default_frequency = 60

    def collect
      [format_metric(online: 1, labels: { pid: Process.pid, version: ENV['APP_VERSION'] })]
    end
  end
end
```
`lib/prometheus/app_ram_processor`
```ruby
require 'get_process_mem'

module Prometheus
  class AppRamProcessor < PrometheusExporterExt::PeriodicProcessor
    self.type = 'app_ram'
    self.logger = Rails.logger
    self.default_frequency = 60

    def collect
      mem = GetProcessMem.new
      [format_metric(usage_bytes: mem.bytes, labels: { pid: Process.pid })]
    end
  end
end
```
`lib/prometheus/some_service_error_processor`
```ruby
module Prometheus
  class SomeServiceErrorProcessor < PrometheusExporterExt::InlineProcessor
    self.type = 'some_service_error'
    self.logger = Rails.logger

    def collect(error_name)
      [
        format_metric(error_count: 1),
        format_metric(specific_error_count: 1, labels: { error_name: error_name })
      ]
    end
  end
end
```

2. Create prometheus initializer  
`config/initializers/prometheus.rb`
```ruby
PrometheusExporterExt.configure do |config|
  config.enabled = ENV['PROMETHEUS_ENABLED']
  config.host = ENV['PROMETHEUS_HOST']
  config.port = ENV['PROMETHEUS_PORT']
  config.default_labels = { node_name: ENV['NODE_NAME'] }
end

if PrometheusExporterExt.enabled?
  require 'prometheus_exporter/middleware'
  require 'prometheus/some_service_error_processor'
  
  Rails.application.middleware.unshift PrometheusExporter::Middleware
  # Here you can also register metrics for ActiveJob adapters like DelayedJob
  # require 'prometheus_exporter/instrumentation/delayed_job'
  # PrometheusExporter::Instrumentation::DelayedJob.register_plugin
end
```

3. Configure puma master/workers to send metrics  
`config/puma.rb`
```ruby
# ...
before_fork do
  # All periodic prometheus processors that needs to monitor web server should be started here.
  if PrometheusExporterExt.enabled?
    require 'prometheus_exporter/instrumentation'
    require 'prometheus/app_online_processor'
    require 'prometheus/app_ram_processor'

    PrometheusExporter::Instrumentation::Puma.start
    PrometheusExporter::Instrumentation::Process.start(type: 'puma_master')
    Prometheus::AppOnlineProcessor.start
    Prometheus::AppRamProcessor.start(labels: { type: 'puma_master' })
    # add here your periodic processors that s 
  end
end

on_worker_boot do
  # All periodic prometheus processors that needs to monitor puma workers should be started here.
  if PrometheusExporterExt.enabled?
    require 'prometheus_exporter/instrumentation'
    require 'prometheus/app_ram_processor'

    PrometheusExporter::Instrumentation::Process.start(type: 'puma_worker')
    Prometheus::AppRamProcessor.start(labels: { type: 'puma_worker' })
  end
end
```

in `SomeService wrote something like`
```ruby
class SomeService
  def call
    # ...
  rescue StandardError => e
    Rails.logger.error { "Error occurred in SomeService: #{e.class} #{e.message}" }
    Prometheus::SomeServiceErrorProcessor.process(e.class.name)
  end
end
```

## How to configure and run prometheus exporter process

1. create collectors that will receive data from our processors.  
`lib/prometheus/app_online_collector`
```ruby
module Prometheus
  class AppOnlineCollector < PrometheusExporterExt::ExpirationCollector
    self.type = 'app_online'
    self.max_metric_age = 70
    
    define_metric_gauge :online, 'application online status'
  end
end
```

`lib/prometheus/app_ram_collector`
```ruby
module Prometheus
  class AppRamCollector < PrometheusExporterExt::ExpirationCollector
    self.type = 'app_ram'
    self.max_metric_age = 70
    
    define_metric_gauge :usage_bytes, 'application ram usage in bytes'
  end
end
```

`lib/prometheus/some_service_error_collector`
```ruby
module Prometheus
  class SomeServiceErrorCollector < PrometheusExporterExt::BaseCollector
    self.type = 'some_service_error'
    
    define_metric_counter :error_count, 'total errors count in SomeService'
    define_metric_counter :specific_error_count, 'errors count in SomeService per error class'
  end
end
```

2. Create file that will load all custom collectors.  
`lib/prometheus_collectors.rb`
```ruby
require_relative 'prometheus/app_online_collector'
require_relative 'prometheus/app_ram_collector'
require_relative 'prometheus/some_service_error_collector'
# Place here require of collectors from 3rd party gems if you have them.
# Collectors from prometheus_exporter will be loaded by default, so no need to require them here.
```

3. Run prometheus_exporter
```shell
$ bundle exec prometheus_exporter -a lib/prometheus_collectors.rb
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can
also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the
version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version,
push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/senid231/prometheus_exporter_ext. This project
is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to
the [code of conduct](https://github.com/senid231/prometheus_exporter_ext/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the PrometheusExporterExt project's codebase, issue trackers, chat rooms and mailing lists is
expected to follow
the [code of conduct](https://github.com/senid231/prometheus_exporter_ext/blob/master/CODE_OF_CONDUCT.md).
