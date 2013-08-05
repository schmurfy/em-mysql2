# Necessary monkeypatching to make AR fiber-friendly.

module ActiveRecord
  module ConnectionAdapters

    # ActiveRecord's connection pool is based on threads.  Since we are working
    # with EM and a single thread, multiple fiber design, we need to provide
    # our own connection pool that keys off of Fiber.current so that different
    # fibers running in the same thread don't try to use the same connection.
    class ConnectionPool
            
      def new_initialize(*args, &block)
        @monitor = FiberTools::Monitor.new
        initialize_original(*args, &block)
        
        @reserved_connections = {}
        @available = ActiveRecord::ConnectionAdapters::ConnectionPool::Queue.new( @monitor )
      end
      
      alias_method :initialize_original, :initialize
      alias_method :initialize, :new_initialize

      def current_connection_id
        Base.connection_id ||= Fiber.current.object_id
      end
      
            
      def synchronize(&block)
        @monitor.synchronize(&block)
      end
      
    end
    
    
    # class ConnectionHandler
    #   def new_initialize(*args, &block)
    #     initialize_original(*args, &block)
        
    #     @owner_to_pool = Hash.new do |h,k|
    #       h[k] = {}
    #     end
    #     @class_to_pool = Hash.new do |h,k|
    #       h[k] = {}
    #     end
    #   end
      
    #   alias_method :initialize_original, :initialize
    #   alias_method :initialize, :new_initialize
    # end

  end
end
