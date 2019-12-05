## 0.1.3
  - Threading problem was proven to be caused by another plugin, unrelated to us. Reverting to a shard concurrency model
  - Upgraded prometheus/client to v1.0.0
## 0.1.2
  - Set to be a single threaded plugin while investigation into deadlocks occurs.
## 0.1.1
  - Fixed bug with unique labels under the same metric name for timers
## 0.1.0
  - Plugin created with the logstash plugin generator
