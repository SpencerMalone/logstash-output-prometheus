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

  # These three create counter/gauge metrics.
  # By default, when increment is used a counter is assumed
  # The hash looks like this:
  # 	increment => {
		# 	mycounter => {
		# 		description => "This is my test counter"
		# 		labels => {
		# 			value => "%{[message]}" 
		# 		}
		# 		type => "counter"
		# 	}
		# }
  config :increment, :validate => :hash, :default => {}
  # Decrement is only available for gauges
  config :decrement, :validate => :hash, :default => {}
  # Decrement is only available for gauges
  config :set, :validate => :hash, :default => {}

  # This creates a summary or histogram
  # Example hashes:
 	# 	timer => {
		# 	histogramtest => {
		# 		description => "This is my histogram"
		# 		value => "%{[timer]}"
		# 		labels => {
		# 			value => "%{[message]}" 
		# 		}
		# 		type => "histogram"
		# 		buckets => [0.1, 1, 5, 10]
		# 	}
		# 	summarytest => {
		# 		description => "This is my summary"
		# 		value => "%{[timer]}"
		# 		type => "summary"
		# 	}
		# }
  config :timer, :validate => :hash, :default => {}

  public
  def register
  	# $prom_servers is a hash of registries with the port as the key
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

      Thread.new do
		Rack::Handler::WEBrick.run(app, Port: @port, BindAddress: "0.0.0.0", Host: "0.0.0.0")
	  end
	end

	prom_server = $prom_servers[@port]

	@increment.each do |metric_name, val|
		if val['labels'].nil?
			val['labels'] = {}
		end

		val['labels'].keys.each do |key|
		  val['labels'][(key.to_sym rescue key) || key] = val['labels'].delete(key)
		end

		if val['type'] == "gauge"
			metric = prom_server.gauge(metric_name.to_sym, docstring: val['description'], labels: val['labels'].keys)
		else
			metric = prom_server.counter(metric_name.to_sym, docstring: val['description'], labels: val['labels'].keys)
		end
		$metrics[metric_name] = metric
	end

	@decrement.each do |metric_name, val|
		if val['labels'].nil?
			val['labels'] = {}
		end

		val['labels'].keys.each do |key|
		  val['labels'][(key.to_sym rescue key) || key] = val['labels'].delete(key)
		end

		metric = prom_server.gauge(metric_name.to_sym, docstring: val['description'], labels: val['labels'].keys)

		$metrics[metric_name] = metric
	end

	@set.each do |metric_name, val|
		if val['labels'].nil?
			val['labels'] = {}
		end

		val['labels'].keys.each do |key|
		  val['labels'][(key.to_sym rescue key) || key] = val['labels'].delete(key)
		end

		metric = prom_server.gauge(metric_name.to_sym, docstring: val['description'], labels: val['labels'].keys)

		$metrics[metric_name] = metric
	end

	@timer.each do |metric_name, val|
		if val['labels'].nil?
			val['labels'] = {}
		end

		val['labels'].keys.each do |key|
		  val['labels'][(key.to_sym rescue key) || key] = val['labels'].delete(key)
		end

		if val['type'] == "histogram"
			metric = prom_server.histogram(metric_name.to_sym, docstring: val['description'], labels: val['labels'].keys, buckets: val['buckets'])
		else
			metric = prom_server.summary(metric_name.to_sym, labels: val['labels'].keys, docstring: val['description'])
		end

		$metrics[metric_name] = metric
	end
  end # def register

  public
  def receive(event)
    @increment.each do |metric_name, val|
      labels = {}
      val['labels'].each do |label, lval|
      	labels[label] = event.sprintf(lval)
      end
      $metrics[metric_name].increment(labels: labels)
    end

    @decrement.each do |metric_name, val|
      labels = {}
      val['labels'].each do |label, lval|
      	labels[label] = event.sprintf(lval)
      end
      $metrics[metric_name].decrement(labels: labels)
    end

    @set.each do |metric_name, val|
      labels = {}
      val['labels'].each do |label, lval|
      	labels[label] = event.sprintf(lval)
      end
      $metrics[metric_name].set(event.sprintf(val['value']).to_f,labels: labels)
    end

    @timer.each do |metric_name, val|
      labels = {}
      val['labels'].each do |label, lval|
      	labels[label] = event.sprintf(lval)
      end
      $metrics[metric_name].observe(event.sprintf(val['value']).to_f,labels: labels)
    end
  end # def event
end # class LogStash::Outputs::Prometheus
