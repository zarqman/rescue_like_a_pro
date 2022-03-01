module RescueLikeAPro::ActiveJob
  extend ActiveSupport::Concern


  prepended do
    rescue_from Exception, with: :rescue_like_a_pro

    class_attribute :retries_exhausted_handler, instance_writer: false, instance_predicate: false
    class_attribute :discard_handler, instance_writer: false, instance_predicate: false
    class_attribute :rescue_pro_rules, instance_writer: false, instance_predicate: false, default: {}
      # {'Module::SomeException' => {..rules..}, ...}
  end

  module ClassMethods

    def retry_on(*exceptions, wait: 3.seconds, attempts: 5, queue: nil, priority: nil, jitter: nil, &block)
      exception_map = exceptions.each_with_object({}) do |exception, h|
        h[exception.to_s] = { action: :retry_on, wait: wait, attempts: attempts, queue: queue, priority: priority, jitter: jitter, handler: block }
      end
      self.rescue_pro_rules = rescue_pro_rules.merge exception_map
    end

    def discard_on(*exceptions, &block)
      exception_map = exceptions.each_with_object({}) do |exception, h|
        h[exception.to_s] = { action: :discard_on, handler: block }
      end
      self.rescue_pro_rules = rescue_pro_rules.merge exception_map
    end

    def on_retries_exhausted(&block)
      self.retries_exhausted_handler = block
    end

    def on_discard(&block)
      self.discard_handler = block
    end

  end


  private

  def rescue_like_a_pro(error)
    rules = lookup_handler(error)
    executions = executions_for([error])
    case rules[:action]
    when :retry_on
      jitter = rules[:jitter] || self.class.retry_jitter
      if rules[:attempts] == :unlimited || executions < rules[:attempts]
        retry_job(
          wait:     determine_delay(seconds_or_duration_or_algorithm: rules[:wait], executions: executions, jitter: jitter),
          queue:    rules[:queue],
          priority: rules[:priority],
          error:    error
        )
        return
      else
        handler  = rules[:handler] || retries_exhausted_handler
        inst_key = :retry_stopped
      end
    when :discard_on
      handler  = rules[:handler] || discard_handler || proc{}
      inst_key = :discard
    end
    if handler
      instrument inst_key, error: error do
        handler.call(*[self, error].take(handler.arity))
      end
    else
      instrument inst_key, error: error
      raise error
    end
    nil
  end

  def lookup_handler(exception)
    ex = exception.class
    while ex
      if r = rescue_pro_rules[ex.to_s]
        return r
      end
      ex = ex.superclass
    end
    raise exception
  end

  def determine_delay(seconds_or_duration_or_algorithm:, executions:, jitter: nil)
    case seconds_or_duration_or_algorithm
    when :exponentially_longer
      delay = executions**4
      delay_jitter = determine_jitter_for_delay(delay, jitter)
      delay + delay_jitter + 2
    when ActiveSupport::Duration, Integer
      delay = seconds_or_duration_or_algorithm.to_i
      delay_jitter = determine_jitter_for_delay(delay, jitter)
      delay + delay_jitter
    when Proc
      algorithm = seconds_or_duration_or_algorithm
      delay = algorithm.call(executions)
      delay_jitter = determine_jitter_for_delay(delay, jitter)
      delay + delay_jitter
    else
      raise "Couldn't determine a delay based on #{seconds_or_duration_or_algorithm.inspect}"
    end
  end

  def determine_jitter_for_delay(delay, jitter)
    if jitter.is_a?(Range) || jitter >= 1.0
      Kernel.rand jitter
    else
      return 0.0 if jitter.zero?
      Kernel.rand * delay * jitter
    end
  end

end
