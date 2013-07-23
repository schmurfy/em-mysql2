
#
# this work is based on the mysql2 0.2.x gem and
# em-synchrony.
# 
module FiberTools

  class Mutex
    def initialize
      @waiters = []
      @slept = {}
    end
    
    def dump_waiters(other = Fiber.current)
      p [@waiters.map{|f| fiber_id(f.object_id).strip.to_i}, fiber_id(other.object_id).strip.to_i]
    end

    def lock
      log("   LOCK:try", self)
      current = Fiber.current
      
      dump_waiters()
      if @waiters.include?(current)
        raise FiberError, "fiber tried to lock the mutex twice"
      end
      
      @waiters << current
      unless @waiters.first == current
        log("   LOCK:waiting_for_lock", self)
        Fiber.yield
      end
      log("   LOCK:ok", self)
      dump_waiters()
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
      self
    end

    def synchronize
      lock
      yield
    ensure
      unlock
    end

  end
  
  
  class ConditionVariable
    #
    # Creates a new ConditionVariable
    #
    def initialize
      @waiters = {}
      @waiters_mutex = Mutex.new
    end

    #
    # Releases the lock held in +mutex+ and waits; reacquires the lock on wakeup.
    #
    # If +timeout+ is given, this method returns after +timeout+ seconds passed,
    # even if no other thread doesn't signal.
    #
    def wait(mutex, timeout=nil)
      # Thread.handle_interrupt(StandardError => :never) do
        begin
          # Thread.handle_interrupt(StandardError => :on_blocking) do
            @waiters_mutex.synchronize do
              @waiters[Fiber.current] = true
            end
            mutex.sleep timeout
          # end
        ensure
          @waiters_mutex.synchronize do
            @waiters.delete(Fiber.current)
          end
        end
      # end
      self
    end

    #
    # Wakes up the first thread in line waiting for this lock.
    #
    def signal
      # Thread.handle_interrupt(StandardError => :on_blocking) do
        begin
          t, _ = @waiters_mutex.synchronize { @waiters.shift }
          t.resume if t
        rescue FiberError
          retry # t was already dead?
        end
      # end
      self
    end

    #
    # Wakes up all threads waiting for this lock.
    #
    def broadcast
      # Thread.handle_interrupt(StandardError => :on_blocking) do
        threads = nil
        @waiters_mutex.synchronize do
          threads = @waiters.keys
          @waiters.clear
        end
        for t in threads
          begin
            t.run
          rescue ThreadError
          end
        end
      # end
      self
    end
  end
  
  class MonitorConditionVariable < MonitorMixin::ConditionVariable
    def initialize(*)
      super
      @cond = ConditionVariable.new
    end
  end
  
  class Monitor
    def initialize
      @mon_mutex = Mutex.new
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
      MonitorConditionVariable.new(self)
    end
  
  private
    #
    # Enters exclusive section.
    #
    def mon_enter
      if @owner != Fiber.current
        log("Waiting ownership")
        @mon_mutex.lock
        log("Got ownership")
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
        @mon_mutex.unlock
        log("Gave up ownership")
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
