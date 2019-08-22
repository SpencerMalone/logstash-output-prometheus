# encoding: utf-8
require "logstash/outputs/base"

require 'prometheus_exporter'
require 'prometheus_exporter/server'

# client allows instrumentation to send info to server
require 'prometheus_exporter/client'

# An prometheus output that does nothing.
class LogStash::Outputs::Prometheus < LogStash::Outputs::Base
  config_name "prometheus"
  concurrency :single

  config :port, :validate => :number, :default => 12345

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
		# 		quantiles => [0.5, 0.9, 0.99]
		# 	}
		# }
  config :timer, :validate => :hash, :default => {}

  public
  def register
  	if $prom_server.nil?
  	  $prom_server = PrometheusExporter::Server::WebServer.new port: @port
	  $prom_server.start

	  $metrics = {}
	end

	@increment.each do |metric_name, val|
		if val['type'] == "gauge"
			metric = PrometheusExporter::Metric::Gauge.new(metric_name, val['description'])
		else
			metric = PrometheusExporter::Metric::Counter.new(metric_name, val['description'])
		end
		$prom_server.collector.register_metric(metric)
		$metrics[metric_name] = metric

		if val['labels'].nil?
			val['labels'] = {}
		end
	end

	@decrement.each do |metric_name, val|
		if val['type'] == "gauge"
			metric = PrometheusExporter::Metric::Gauge.new(metric_name, val['description'])
		else
			metric = PrometheusExporter::Metric::Counter.new(metric_name, val['description'])
		end
		$prom_server.collector.register_metric(metric)
		$metrics[metric_name] = metric

		if val['labels'].nil?
			val['labels'] = {}
		end
	end

	@set.each do |metric_name, val|
		metric = PrometheusExporter::Metric::Gauge.new(metric_name, val['description'])

		$prom_server.collector.register_metric(metric)
		$metrics[metric_name] = metric

		if val['labels'].nil?
			val['labels'] = {}
		end
	end

	@timer.each do |metric_name, val|
		if val['type'] == "histogram"
			metric = PrometheusExporter::Metric::Histogram.new(metric_name, val['description'], buckets: val['buckets'])
		else
			if val['quantiles'].nil?
				val['quantiles'] = [0.99, 0.9, 0.5]
			end
			metric = PrometheusExporter::Metric::Summary.new(metric_name, val['description'], quantiles: val['quantiles'])
		end

		$prom_server.collector.register_metric(metric)
		$metrics[metric_name] = metric

		if val['labels'].nil?
			val['labels'] = {}
		end
	end
  end # def register

  public
  def receive(event)
    @increment.each do |metric_name, val|
      labels = {}
      val['labels'].each do |label, lval|
      	labels[label] = event.sprintf(lval)
      end
      $metrics[metric_name].increment(labels)
    end

    @decrement.each do |metric_name, val|
      labels = {}
      val['labels'].each do |label, lval|
      	labels[label] = event.sprintf(lval)
      end
      $metrics[metric_name].decrement(labels)
    end

    @set.each do |metric_name, val|
      labels = {}
      val['labels'].each do |label, lval|
      	labels[label] = event.sprintf(lval)
      end
      $metrics[metric_name].set(event.sprintf(val['value']),labels)
    end

    @timer.each do |metric_name, val|
      labels = {}
      val['labels'].each do |label, lval|
      	labels[label] = event.sprintf(lval)
      end
      $metrics[metric_name].observe(event.sprintf(val['value']),labels)
    end
  end # def event
end # class LogStash::Outputs::Prometheus
