Gem::Specification.new do |s|
  s.name          = 'logstash-output-prometheus'
  s.version       = '0.1.1'
  s.licenses      = ['Apache-2.0']
  s.summary       = 'Output logstash data to a prometheus exporter'
#  s.homepage      = 'Nada'
  s.authors       = ['Spencer Malone']
  s.email         = 'spencer@mailchimp.com'
  s.require_paths = ['lib']

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT']
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "output" }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core-plugin-api", "~> 2.0"
  s.add_runtime_dependency "logstash-codec-plain"
  s.add_runtime_dependency "prometheus-client", "0.10.0.pre.alpha.2"
  s.add_runtime_dependency "rack", ">= 1.6.11"

  s.add_development_dependency "logstash-devutils", "~> 1.3", ">= 1.3.1"
end
