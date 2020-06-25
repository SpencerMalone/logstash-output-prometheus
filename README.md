# Logstash Plugin

This is a plugin for [Logstash](https://github.com/elastic/logstash).

It is fully free and fully open source. The license is Apache 2.0, meaning you are pretty much free to use it however you want in whatever way.

This plugin allows you to expose metrics from logstash to a prometheus exporter, hosted by your logstash instance.


## Building

### Requirements
- JRuby
- JDK
- Git
- bundler

### Build steps

`./script/build`

## Contributing

All contributions are welcome: ideas, patches, documentation, bug reports, complaints, and even something you drew up on a napkin.

Programming is not a required skill. Whatever you've seen about open source and maintainers or community members  saying "send patches or die" - you will not see that here.

It is more important to the community that you are able to contribute.

For more information about contributing, see the [CONTRIBUTING](https://github.com/elastic/logstash/blob/master/CONTRIBUTING.md) file.

## Examples

```
logstash -e 'input { stdin { } }
filter {
	mutate {
		add_field => {
			"timer" => "%{[message]}"
		}
	}
	mutate {
		convert      => { "timer" => "float" }
	}
}
output {
	prometheus {
		timer => {
			histogramtest => {
				description => "This is my histogram"
				value => "%{[timer]}"
				type => "histogram"
				buckets => [0.1, 1, 5, 10]
				labels => {
					mylabel => "testlabel"
				}
			}
		}
	}
	prometheus {
		port => 9641 # You can run multiple ports if you want different outputs scraped by different prom instances.
		timer => {
			summarytest => {
				description => "This is my summary"
				value => "%{[timer]}"
				type => "summary"
			}
		}
	}
}'
```

```
logstash -e 'input { stdin { } }
output {
	prometheus {
		increment => {
			mycounter => {
				description => "This is my test counter"
				labels => {
					value => "%{[message]}"
				}
                by => "1"
				type => "counter"
			}
		}
	}

	prometheus {
		increment => {
			totaleventscustom => {
				description => "This is my second test counter"
			}
		}
	}
}'
```

## Things to keep in mind

As outlined in https://www.robustperception.io/putting-queues-in-front-of-prometheus-for-reliability, putting a queue in front of Prometheus can have negative effects. When doing this, please ensure you are monitoring the time it takes events to pass through your queue.

## Steps towards a 1.0 release

Things needed for a 1.0 release:
- Official logstash adoption (nice to have). See: https://github.com/elastic/logstash/issues/11153
- ~`prometheus-client` over at https://github.com/prometheus/client_ruby is still in alpha.~ This has now been solved.
- A stable release without known errors for one month.
