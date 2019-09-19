# encoding: utf-8
require "logstash/outputs/base"
require 'rack'
require 'prometheus/middleware/exporter'
require 'prometheus/middleware/collector'
require 'prometheus/client'

# An prometheus output that does nothing.
class LogStash::Outputs::Prometheus < LogStash::Outputs::Base
  config_name "prometheus"
  concurrency :shared

  config :port, :validate => :number, :default => 9640

  # When working with gauges or counters, specify one of the following three hash objects
  # By default, when increment is used a counter is assumed
  # Decrement and set are available only for gauges
  # The hashes generally look like this:
  # [source,ruby]
  # ----------------------------------
  # increment => {
  #     events_count => {
  #         description => "This is my test counter"
  #         labels => {
  #             mylabel => "%{[message]}" 
  #         }
  #         type => "counter"
  #     }
  # }
  # decrement => {
  #     negaevents_total => {
  #         description => "This is my test counter"
  #         labels => {
  #             mylabel => "%{[message]}" 
  #         }
  #         type => "counter"
  #     }
  # }
  # set => {
  #     onetwothree_current => {
  #         description => "This is my test counter"
  #         labels => {
  #             mylabel => "%{[message]}" 
  #         }
  #         value => 123
  #         type => "counter"
  #     }
  # }
  # ----------------------------------
  config :increment, :validate => :hash, :default => {}
  # Decrement is only available for gauges
  config :decrement, :validate => :hash, :default => {}
  # Decrement is only available for gauges
  config :set, :validate => :hash, :default => {}

  # This creates a summary or histogram
  # Example hashes:
  # [source,ruby]
  # ----------------------------------
  # timer => {
  #     histogramtest => {
  #         description => "This is my histogram"
  #         value => "%{[timer]}"
  #         labels => {
  #             value => "%{[message]}" 
  #         }
  #         type => "histogram"
  #         buckets => [0.1, 1, 5, 10]
  #     }
  #     summarytest => {
  #         description => "This is my summary"
  #         value => "%{[timer]}"
  #         type => "summary"
  #     }
  # }
  # ----------------------------------
  # Something to note: due to implementation details of https://github.com/prometheus/client_ruby, summaries only contain the count and sum, and will not track any quantiles.

  config :timer, :validate => :hash, :default => {}

  public
  def register
    $prom_servers ||= {}
    $metrics ||= {}

    if $prom_servers[@port].nil?
      $prom_servers[@port] = Prometheus::Client::Registry.new
      prom_server = $prom_servers[@port]

      app =
      Rack::Builder.new(@port) do
        use ::Rack::Deflater
        use ::Prometheus::Middleware::Exporter, registry: prom_server

        run ->(_) { [200, {'Content-Type' => 'text/html'}, ['Please access /metrics to see exposed metrics for this Logstash instance.']] }
      end.to_app

      @thread = Thread.new do
        Rack::Handler::WEBrick.run(app, Port: @port, BindAddress: "0.0.0.0", Host: "0.0.0.0")
      end
    end

    prom_server = $prom_servers[@port]

    @increment.each do |metric_name, val|
    	val = setup_registry_labels(val)
      if $metrics[port.to_s + metric_name].nil?
        if val['type'] == "gauge"
          metric = prom_server.gauge(metric_name.to_sym, docstring: val['description'], labels: val['labels'].keys)
        else
          metric = prom_server.counter(metric_name.to_sym, docstring: val['description'], labels: val['labels'].keys)
        end
        $metrics[port.to_s + metric_name] = metric
      end
    end

    @decrement.each do |metric_name, val|
      val = setup_registry_labels(val)
      if $metrics[port.to_s + metric_name].nil?
        metric = prom_server.gauge(metric_name.to_sym, docstring: val['description'], labels: val['labels'].keys)

        $metrics[port.to_s + metric_name] = metric
      end
    end

    @set.each do |metric_name, val|
      val = setup_registry_labels(val)
      if $metrics[port.to_s + metric_name].nil?
        metric = prom_server.gauge(metric_name.to_sym, docstring: val['description'], labels: val['labels'].keys)

        $metrics[port.to_s + metric_name] = metric
      end
    end

    @timer.each do |metric_name, val|
      val = setup_registry_labels(val)

      if val['type'] == "histogram"
        metric = prom_server.histogram(metric_name.to_sym, docstring: val['description'], labels: val['labels'].keys, buckets: val['buckets'])
      else
        metric = prom_server.summary(metric_name.to_sym, labels: val['labels'].keys, docstring: val['description'])
      end

      $metrics[port.to_s + metric_name] = metric
    end
  end # def register

  def kill_thread()
  	@thread.kill
  	$prom_servers[@port] = nil
  end

  protected
  def setup_registry_labels(val)
    if val['labels'].nil?
      val['labels'] = {}
    end

    val['labels'].keys.each do |key|
      val['labels'][(key.to_sym rescue key) || key] = val['labels'].delete(key)
    end

    return val     
  end

  public
  def receive(event)
    @increment.each do |metric_name, val|
      labels = setup_event_labels(val)
      $metrics[port.to_s + metric_name].increment(labels: labels)
    end

    @decrement.each do |metric_name, val|
      labels = setup_event_labels(val)
      $metrics[port.to_s + metric_name].decrement(labels: labels)
    end

    @set.each do |metric_name, val|
      labels = setup_event_labels(val)
      $metrics[port.to_s + metric_name].set(event.sprintf(val['value']).to_f,labels: labels)
    end

    @timer.each do |metric_name, val|
      labels = setup_event_labels(val)
      $metrics[port.to_s + metric_name].observe(event.sprintf(val['value']).to_f,labels: labels)
    end
  end # def event

  protected
  def setup_event_labels(val)
    labels = {}
    val['labels'].each do |label, lval|
      labels[label] = event.sprintf(lval)
    end

    return labels     
  end
end # class LogStash::Outputs::Prometheus
