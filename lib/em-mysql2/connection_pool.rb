# Necessary monkeypatching to make AR fiber-friendly.

module ActiveRecord
  module ConnectionAdapters

    def self.fiber_pools
      @fiber_pools ||= []
    end
    def self.register_fiber_pool(fp)
      fiber_pools << fp
    end

    class FiberedMonitor
      class Queue
        def initialize
          @queue = []
        end

        def wait(timeout)
          t = timeout || 5
          fiber = Fiber.current
          x = EM::Timer.new(t) do
            @queue.delete(fiber)
            fiber.resume(false)
          end
          @queue << fiber
          Fiber.yield.tap do
            x.cancel
          end
        end

        def signal
          fiber = @queue.pop
          fiber.resume(true) if fiber
        end
      end

      def synchronize
        yield
      end

      def new_cond
        Queue.new
      end
    end

    # ActiveRecord's connection pool is based on threads.  Since we are working
    # with EM and a single thread, multiple fiber design, we need to provide
    # our own connection pool that keys off of Fiber.current so that different
    # fibers running in the same thread don't try to use the same connection.
    class ConnectionPool
            
      # def new_initialize(*args, &block)
      #   @monitor = FiberTools::Monitor.new
      #   initialize_original(*args, &block)
        
      #   @reserved_connections = {}
      #   @available = ActiveRecord::ConnectionAdapters::ConnectionPool::Queue.new( FiberTools::Monitor.new )
      # end
      
      # alias_method :initialize_original, :initialize
      # alias_method :initialize, :new_initialize

      # def current_connection_id #:nodoc:
      #   Base.connection_id ||= Fiber.current.object_id
      # end
      
            
      # def synchronize(&block)
      #   @monitor.synchronize(&block)
      # end
      
      
      
    end

  end
end
