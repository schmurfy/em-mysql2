
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
    
    def lock
      current = Fiber.current
      
      if @waiters.include?(current)
        raise FiberError, "fiber tried to lock the mutex twice"
      end
      
      @waiters << current
      unless @waiters.first == current
        Fiber.yield
      end
      
      true
    end

    def locked?
      !@waiters.empty?
    end

    def _wakeup(fiber)
      fiber.resume if @slept.delete(fiber)
    end

    def sleep(timeout = nil)
      unlock
      beg = Time.now
      current = Fiber.current
      @slept[current] = true
      if timeout
        timer = EM.add_timer(timeout) do
          _wakeup(current)
        end
        Fiber.yield
        EM.cancel_timer timer # if we resumes not via timer
      else
        Fiber.yield
      end
      @slept.delete current
      yield if block_given?
      lock
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
      mon_enter()
      begin
        yield
      ensure
        mon_exit()
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
        @mon_mutex.lock
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
