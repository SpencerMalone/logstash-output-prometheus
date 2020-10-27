# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/prometheus"
require "logstash/codecs/plain"
require "logstash/event"
require 'net/http'

describe LogStash::Outputs::Prometheus do
  let(:port) { rand(2000..10000) }
  let(:host) { "0.0.0.0" }
  let(:output) { LogStash::Outputs::Prometheus.new(properties) }
  let(:secondary_output) {
    if secondary_properties.nil?
      LogStash::Outputs::Prometheus.new(properties)
    else
      LogStash::Outputs::Prometheus.new(secondary_properties)
    end
  }

  before do
    output.register
    secondary_output.register
  end

  let(:secondary_properties) do
    nil
  end

  let(:event) do
    LogStash::Event.new(
      properties
    )
  end

  let(:secondary_event) do
    if secondary_properties.nil?
      LogStash::Event.new(
        secondary_properties
      )
    else
      event
    end
  end

  shared_examples "it should expose data" do |*values|
    it "should expose data" do
      output.receive(event)

      url = URI.parse("http://localhost:#{port}/metrics")
      req = Net::HTTP::Get.new(url.to_s)

      attempts = 0

      begin
        res = Net::HTTP.start(url.host, url.port) {|http|
            http.request(req)
        }
      rescue
        attempts++
        sleep(0.1)
        if attempts < 10
          retry
        end
      end

      values.each do |value|
        expect(res.body).to include(value)
      end
    end
  end

  shared_examples "it should expose data from multiple outputs" do |*values|
    it "should be able to handle unique labels under the same name" do
      secondary_output.receive(secondary_event)

      output.receive(event)

      url = URI.parse("http://localhost:#{port}/metrics")
      req = Net::HTTP::Get.new(url.to_s)

      attempts = 0

      begin
        res = Net::HTTP.start(url.host, url.port) {|http|
            http.request(req)
        }
      rescue
        attempts++
        sleep(0.1)
        if attempts < 10
          retry
        end
      end

      values.each do |value|
        expect(res.body).to include(value)
      end
    end
  end

  describe "counter behavior" do
    describe "default increment" do
      let(:properties) {
        {
          "port" => port,
          "host" => host,
          "increment" => {
            "basic_counter" => {
              "description" => "Test",
              "labels" => {
                "mylabel" => "hi"
              }
            }
          }
        }
      }

      let(:secondary_properties) {
        {
          "port" => port,
          "host" => host,
          "increment" => {
            "basic_counter" => {
              "description" => "Test",
              "labels" => {
                "mylabel" => "boo"
              }
            }
          }
        }
      }

      include_examples "it should expose data", 'basic_counter{mylabel="hi"} 1', "# TYPE basic_counter counter", "# HELP basic_counter Test"
      include_examples "it should expose data from multiple outputs", 'basic_counter{mylabel="hi"} 1', 'basic_counter{mylabel="boo"} 1'

    end

    describe "custom increment by" do
      let(:properties) {
        {
          "port" => port,
          "host" => host,
          "increment" => {
            "basic_counter" => {
              "description" => "Test",
              "by" => "5",
              "labels" => {
                "mylabel" => "hi"
              }
            }
          }
        }
      }

      let(:secondary_properties) {
        {
          "port" => port,
          "host" => host,
          "increment" => {
            "basic_counter" => {
              "description" => "Test",
              "by" => "10",
              "labels" => {
                "mylabel" => "boo"
              }
            }
          }
        }
      }

      include_examples "it should expose data", 'basic_counter{mylabel="hi"} 5', "# TYPE basic_counter counter", "# HELP basic_counter Test"
      include_examples "it should expose data from multiple outputs", 'basic_counter{mylabel="hi"} 5', 'basic_counter{mylabel="boo"} 10'

    end
  end

  describe "gauge behavior" do
    describe "increment" do
      let(:properties) {
        {
          "port" => port,
          "host" => host,
          "increment" => {
            "basic_gauge" => {
              "description" => "Test1",
              "labels" => {
                "mylabel" => "hi"
              },
              "type" => "gauge"
            }
          }
        }
      }

      let(:secondary_properties) {
        {
          "port" => port,
          "host" => host,
          "increment" => {
            "basic_gauge" => {
              "description" => "Test1",
              "type" => "gauge",
              "labels" => {
                "mylabel" => "boo"
              }
            }
          }
        }
      }

      include_examples "it should expose data", 'basic_gauge{mylabel="hi"} 1.0', "# TYPE basic_gauge gauge", "# HELP basic_gauge Test1"
      include_examples "it should expose data from multiple outputs", 'basic_gauge{mylabel="hi"} 1', 'basic_gauge{mylabel="boo"} 1'
    end
    describe "increment with custom by" do
      let(:properties) {
        {
          "port" => port,
          "host" => host,
          "increment" => {
            "basic_gauge" => {
              "description" => "Test1",
              "by" => "5",
              "type" => "gauge"
            }
          }
        }
      }
      include_examples "it should expose data", "basic_gauge 5.0", "# TYPE basic_gauge gauge", "# HELP basic_gauge Test1"
    end

    describe "decrement" do
      let(:properties) {
        {
          "port" => port,
          "host" => host,
          "decrement" => {
            "basic_gauge" => {
              "description" => "Testone",
              "type" => "gauge"
            }
          }
        }
      }
      include_examples "it should expose data", "basic_gauge -1.0", "# TYPE basic_gauge gauge", "# HELP basic_gauge Testone"
    end

    describe "decrement with custom by" do
      let(:properties) {
        {
          "port" => port,
          "host" => host,
          "decrement" => {
            "basic_gauge" => {
              "description" => "Testone",
              "by" => "10",
              "type" => "gauge"
            }
          }
        }
      }
      include_examples "it should expose data", "basic_gauge -10.0", "# TYPE basic_gauge gauge", "# HELP basic_gauge Testone"
    end

    describe "set" do
      let(:properties) {
        {
          "port" => port,
          "host" => host,
          "set" => {
            "basic_gauge" => {
              "description" => "Testone",
              "type" => "gauge",
              "value" => "123"
            }
          }
        }
      }
      include_examples "it should expose data", "basic_gauge 123.0", "# TYPE basic_gauge gauge", "# HELP basic_gauge Testone"
    end
  end

  describe "summary behavior" do
    let(:properties) {
      {
        "port" => port,
        "host" => host,
        "timer" => {
          "huh" => {
            "description" => "noway",
            "type" => "summary",
            "value" => "11",
            "labels" => {
              "mylabel" => "hi"
            }
          }
        }
      }
    }

    let(:secondary_properties) {
      {
        "port" => port,
        "host" => host,
        "timer" => {
          "huh" => {
            "description" => "noway",
            "type" => "summary",
            "value" => "10",
            "labels" => {
              "mylabel" => "boo"
            }
          }
        }
      }
    }
    include_examples "it should expose data", 'huh_sum{mylabel="hi"} 11.0', 'huh_count{mylabel="hi"} 1.0', "# TYPE huh summary", "# HELP huh noway"
    include_examples "it should expose data from multiple outputs", 'huh_sum{mylabel="hi"} 11.0', 'huh_sum{mylabel="boo"} 10.0'
  end

  describe "histogram behavior" do
    describe "description" do
      let(:properties) {
        {
          "port" => port,
          "host" => host,
          "timer" => {
            "history" => {
              "description" => "abe",
              "type" => "histogram",
              "buckets" => [1, 5, 10],
              "value" => "0",
              "labels" => {
                "mylabel" => "hi"
              }
            }
          }
        }
      }
      let(:secondary_properties) {
        {
          "port" => port,
          "host" => host,
          "timer" => {
            "history" => {
              "description" => "abe",
              "type" => "histogram",
              "buckets" => [1, 5, 10],
              "value" => "0",
              "labels" => {
                "mylabel" => "boo"
              }
            }
          }
        }
      }
      include_examples "it should expose data", "# TYPE history histogram", "# HELP history abe"
      include_examples "it should expose data from multiple outputs", 'history_sum{mylabel="hi"} 0.0', 'history_sum{mylabel="boo"} 0.0'
    end

    describe "sum and count" do
      let(:properties) {
        {
          "port" => port,
          "host" => host,
          "timer" => {
            "history" => {
              "description" => "abe",
              "type" => "histogram",
              "buckets" => [1, 5, 10],
              "value" => "111"
            }
          }
        }
      }
      include_examples "it should expose data", "history_sum 111.0", "history_count 1.0"
    end

    describe "minimum histogram" do
      let(:properties) {
        {
          "port" => port,
          "host" => host,
          "timer" => {
            "history" => {
              "description" => "abe",
              "type" => "histogram",
              "buckets" => [1, 5, 10],
              "value" => "0"
            }
          }
        }
      }
      include_examples "it should expose data", 'history_bucket{le="1"} 1.0', 'history_bucket{le="5"} 1.0', 'history_bucket{le="10"} 1.0', 'history_bucket{le="+Inf"} 1.0'
    end

    describe "middle histogram" do
      let(:properties) {
        {
          "port" => port,
          "host" => host,
          "timer" => {
            "history" => {
              "description" => "abe",
              "type" => "histogram",
              "buckets" => [1, 5, 10],
              "value" => "5"
            }
          }
        }
      }
      include_examples "it should expose data", 'history_bucket{le="1"} 0.0', 'history_bucket{le="5"} 0.0', 'history_bucket{le="10"} 1.0', 'history_bucket{le="+Inf"} 1.0'
    end

    describe "max histogram" do
      let(:properties) {
        {
          "port" => port,
          "host" => host,
          "timer" => {
            "history" => {
              "description" => "abe",
              "type" => "histogram",
              "buckets" => [1, 5, 10],
              "value" => "9"
            }
          }
        }
      }
      include_examples "it should expose data", 'history_bucket{le="1"} 0.0', 'history_bucket{le="5"} 0.0', 'history_bucket{le="10"} 1.0', 'history_bucket{le="+Inf"} 1.0'
    end

    describe "beyond max histogram" do
      let(:properties) {
        {
          "port" => port,
          "host" => host,
          "timer" => {
            "history" => {
              "description" => "abe",
              "type" => "histogram",
              "buckets" => [1, 5, 10],
              "value" => "100"
            }
          }
        }
      }
      include_examples "it should expose data", 'history_bucket{le="1"} 0.0', 'history_bucket{le="5"} 0.0', 'history_bucket{le="10"} 0.0', 'history_bucket{le="+Inf"} 1.0'
    end

  end
end
