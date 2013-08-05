
# What is this ?

This gem allow you to use activerecord + mysql2 with fibers, the old em_mysql2 driver from the mysql2 gem was use as a foundation.

# Why ?

The "new" em_mysql2 driver lives in em-synchrony but it is far from prefect, instead of trying to keep the same behavior as the threaded version it just patch activerecord enough to make it work.

I don't pretend my implementation is perfect but at least I try to keep the same behavior.

# Supported ActiveRecord version

This gem currently support 4.0.0


# Example:

```ruby
require 'rubygems'
require 'bundler/setup'

require 'active_record'
require 'em-mysql2'

ActiveRecord::Base.establish_connection(
  adapter:          'em_mysql2',
  database:         'test',
  username:         'root',
  pool:             2,
  checkout_timeout: 30,
  socket:           '/tmp/mysql_ram.sock'
)

ActiveRecord::Base.logger = Logger.new($stdout)

COUNT = 5
started_at = Time.now

EM::run do
  left = COUNT
  
  
  COUNT.times do |n|
    Fiber.new do
      
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.connection.execute("SELECT SLEEP(2)")
      end
      
      left -= 1
      if left <= 0
        EM::stop()
      end
    end.resume
  end
  
  
end


elapsed = (Time.now - started_at)
puts "time: #{'%.2f' % elapsed} seconds"

```
