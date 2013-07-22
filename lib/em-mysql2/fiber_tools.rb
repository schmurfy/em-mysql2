
#
# this work is based on the mysql2 0.2.x gem and
# em-synchrony.
# 
module FiberTools
  
  class Queue < Array
    def add(what)
      
    end
    
    def delete()
      
    end
    
    def clear
      
    end
    
    def any_waiting?
      
    end
    
    
    # def wait(timeout)
    #   t = timeout || 5
    #   fiber = Fiber.current
    #   x = EM::Timer.new(t) do
    #     @queue.delete(fiber)
    #     fiber.resume(false)
    #   end
    #   @queue << fiber
    #   Fiber.yield.tap do
    #     x.cancel
    #   end
    # end
    
    
    def can_remove_no_wait?
      
    end
    
    
    def poll(timeout)
      
    end

    # def signal
    #   fiber = @queue.pop
    #   fiber.resume(true) if fiber
    # end
  end

  class Mutex
    def initialize
      @waiters = []
      @slept = {}
    end

    def lock
      log("   LOCK:try", self)
      current = Fiber.current
      raise FiberError if @waiters.include?(current)
      @waiters << current
      Fiber.yield unless @waiters.first == current
      log("   LOCK:ok", self)
      true
    end

    def locked?
      !@waiters.empty?
    end

    def _wakeup(fiber)
      fiber.resume if @slept.delete(fiber)
    end

    def sleep(timeout = nil)
      log("   Mutex::sleep(#{timeout})")
      unlock
      beg = Time.now
      current = Fiber.current
      @slept[current] = true
      if timeout
        timer = EM.add_timer(timeout) do
          _wakeup(current)
        end
        log("   Mutex::sleep(#{timeout}) - 1")
        Fiber.yield
        log("   Mutex::sleep(#{timeout}) - 2")
        EM.cancel_timer timer # if we resumes not via timer
      else
        Fiber.yield
      end
      @slept.delete current
      log("   Mutex::sleep(#{timeout}) - 3")
      yield if block_given?
      log("   Mutex::sleep(#{timeout}) - 4")
      lock
      log("   Mutex::sleep(#{timeout}) - 5")
      Time.now - beg
    end

    def try_lock
      lock unless locked?
    end

    def unlock
      raise FiberError unless @waiters.first == Fiber.current  
      @waiters.shift
      unless @waiters.empty?
        EM.next_tick{ @waiters.first.resume }
      end
      log("   LOCK:unlock", self)
      self
    end

    def synchronize
      lock
      yield
    ensure
      unlock
    end

  end
  
  
  # class ConditionVariable
  #   def initialize
  #     @queue = []
  #   end

  #   def wait(timeout = nil)
  #     t = timeout || 5
  #     fiber = Fiber.current
  #     x = EM::Timer.new(t) do
  #       @queue.delete(fiber)
  #       fiber.resume(false)
  #     end
  #     @queue << fiber
  #     Fiber.yield.tap do
  #       x.cancel
  #     end
  #   end

  #   def signal
  #     fiber = @queue.pop
  #     fiber.resume(true) if fiber
  #   end
  # end
  
  class MonitorConditionVariable
    def initialize(m)
      @mutex = m
      @queue = []
    end
    
    # def wait(timeout)
    #   t = timeout || 5
    #   fiber = Fiber.current
    #   @queue << fiber
    #   p [:A]
    #   @mutex.sleep(timeout)
    #   p [:B]
    # end

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
  
  class Monitor
    def initialize
      @mutex = Mutex.new
      @owner = nil
      @count = 0
    end
    
    def synchronize
      log("  synchronize start #{@count}", self)
      mon_enter()
      begin
        yield
      ensure
        mon_exit()
        log("  synchronize end #{@count}", self)
      end
    end
    
    def new_cond
      MonitorConditionVariable.new(@mutex)
    end
  
  private
    #
    # Enters exclusive section.
    #
    def mon_enter
      if @owner != Fiber.current
        @mutex.lock
        @owner = Fiber.current
      end
      @count += 1
    end

    #
    # Leaves exclusive section.
    #
    def mon_exit
      mon_check_owner
      @count -=1
      if @count == 0
        @owner = nil
        @mutex.unlock
      end
    end
    
    def mon_check_owner
      if @owner != Fiber.current
        raise FiberError, "current fiber not owner"
      end
    end
    
    def mon_enter_for_cond(count)
      @owner = Fiber.current
      @count = count
    end

    def mon_exit_for_cond
      count = @count
      @owner = nil
      @count = 0
      return count
    end

    
  end

end
