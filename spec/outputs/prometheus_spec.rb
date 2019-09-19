# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/prometheus"
require "logstash/codecs/plain"
require "logstash/event"
require 'net/http'

describe LogStash::Outputs::Prometheus do
  let(:port) { rand(2000..10000) }
  let(:output) { LogStash::Outputs::Prometheus.new(properties) }

  before do
    output.register
  end

  after do
    output.kill_thread
  end

  let(:event) do
    LogStash::Event.new(
      properties
    )
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

  describe "counter behavior" do
    let(:properties) {
      { 
        "port" => port,
        "increment" => { 
          "basic_counter" => { 
            "description" => "Test",
          }
        }
      }
    }

    include_examples "it should expose data", "basic_counter 1.0", "# TYPE basic_counter counter", "# HELP basic_counter Test"
  end

  describe "gauge behavior" do
    describe "increment" do
      let(:properties) {
        { 
          "port" => port,
          "increment" => { 
            "basic_gauge" => { 
              "description" => "Test1",
              "type" => "gauge"
            }
          }
        }
      }
      include_examples "it should expose data", "basic_gauge 1.0", "# TYPE basic_gauge gauge", "# HELP basic_gauge Test1"
    end

    describe "decrement" do
      let(:properties) {
        { 
          "port" => port,
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

    describe "set" do
      let(:properties) {
        { 
          "port" => port,
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
        "timer" => { 
          "huh" => { 
            "description" => "noway",
            "type" => "summary",
            "value" => "11"
          }
        }
      }
    }
    include_examples "it should expose data", "huh_sum 11.0", "huh_count 1.0", "# TYPE huh summary", "# HELP huh noway"
  end

  describe "histogram behavior" do
    describe "description" do
      let(:properties) {
        { 
          "port" => port,
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
      include_examples "it should expose data", "# TYPE history histogram", "# HELP history abe"
    end

    describe "sum and count" do
      let(:properties) {
        { 
          "port" => port,
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
