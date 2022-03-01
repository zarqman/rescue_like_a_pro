require "test_helper"

class RescueLikeAProTest < ActiveJob::TestCase
  class Discard < RuntimeError ; end
  class Retry   < RuntimeError ; end
  class Retry2  < Retry ; end
  class Retry3  < Retry2 ; end

  class BaseJob < ActiveJob::Base
  end
  class DiscardableJob < BaseJob
    def perform
      raise Discard
    end
  end
  class RetryableJob < BaseJob
    def perform(fails: 1, klass: Retry)
      raise klass if executions <= fails
      :okay
    end
  end

  setup do
    BaseJob.rescue_pro_rules          = {}
    BaseJob.discard_handler           = nil
    BaseJob.retries_exhausted_handler = nil
    [DiscardableJob, RetryableJob].each do |klass|
      %i(rescue_pro_rules discard_handler retries_exhausted_handler).each do |meth|
        klass.singleton_class.remove_method meth
      rescue NameError
      end
    end
  end

  test "use more specific exception on parent over less specific on jobclass" do
    scope = nil
    BaseJob.retry_on(Retry2, attempts: 1){ scope = :base }
    RetryableJob.retry_on('RescueLikeAProTest::Retry', attempts: 1){ scope = :job }

    RetryableJob.perform_now klass: Retry2
    assert_equal :base, scope

    scope = nil
    RetryableJob.perform_now klass: Retry
    assert_equal :job, scope

    scope = nil
    RetryableJob.perform_now klass: Retry3
    assert_equal :base, scope
  end

  test "with default options" do
    assert_equal :okay, RetryableJob.perform_now(fails: 0)

    j = RetryableJob.new fails: 1
    assert_raises Retry do
      j.perform_now
    end
    assert_equal :okay, j.perform_now
  end

  test "passthrough unregistered exception" do
    assert_raises Discard do
      DiscardableJob.perform_now
    end
  end

  test "blocks handle varying arity" do
    j = DiscardableJob.new
    args = nil
    DiscardableJob.discard_on(Discard){ args = 0 }
    j.perform_now
    assert_equal 0, args

    DiscardableJob.discard_on(Discard){|job| args = [job] }
    j.perform_now
    assert_equal [j], args

    DiscardableJob.discard_on(Discard){|job, error| args = [job, error.class] }
    j.perform_now
    assert_equal [j, Discard], args
  end

  test "discard_on: jobclass" do
    DiscardableJob.discard_on Discard
    assert_nothing_raised do
      DiscardableJob.perform_now
    end

    action = nil
    DiscardableJob.discard_handler = ->{ action = :default_handler }
    assert_nothing_raised do
      DiscardableJob.perform_now
    end
    assert_equal :default_handler, action

    action = nil
    DiscardableJob.discard_on(Discard){ action = :discard }
    assert_nothing_raised do
      DiscardableJob.perform_now
    end
    assert_equal :discard, action
  end

  test "discard_on: parent" do
    BaseJob.discard_on Discard
    assert_nothing_raised do
      DiscardableJob.perform_now
    end

    action = nil
    BaseJob.on_discard{ action = :default_handler }
    assert_nothing_raised do
      DiscardableJob.perform_now
    end
    assert_equal :default_handler, action

    action = nil
    BaseJob.discard_on(Discard){ action = :discard }
    assert_nothing_raised do
      DiscardableJob.perform_now
    end
    assert_equal :discard, action
  end

  test "retry_on: jobclass" do
    RetryableJob.retry_on Retry, attempts: 2
    # => fail, success
    j = RetryableJob.new fails: 1
    assert_difference 'j.executions', +1 do
      refute_equal :okay, j.perform_now
    end
    assert_equal :okay, j.perform_now

    # => fail
    action = nil
    RetryableJob.retry_on Retry, attempts: 1
    RetryableJob.retries_exhausted_handler = ->{ action = :retry_jobclass }
    refute_equal :okay, RetryableJob.perform_now
    assert_equal :retry_jobclass, action

    action = nil
    RetryableJob.retry_on(Retry, attempts: 1){ action = :retry }
    refute_equal :okay, RetryableJob.perform_now
    assert_equal :retry, action
  end

  test "retry_on: jobclass w/parent handlers" do
    action = nil
    BaseJob.retry_on Retry, attempts: 1
    BaseJob.on_retries_exhausted{ action = :retry_parent_class }
    refute_equal :okay, RetryableJob.perform_now
    assert_equal :retry_parent_class, action

    action = nil
    BaseJob.retry_on(Retry, attempts: 1){ action = :retry_parent }
    refute_equal :okay, RetryableJob.perform_now
    assert_equal :retry_parent, action

    action = nil
    RetryableJob.retry_on(Retry, attempts: 1){ action = :retry }
    refute_equal :okay, RetryableJob.perform_now
    assert_equal :retry, action
  end

  test "retry_on: parent" do
    BaseJob.retry_on Retry, attempts: 2
    # => fail, success
    j = RetryableJob.new fails: 1
    assert_difference 'j.executions', +1 do
      refute_equal :okay, j.perform_now
    end
    assert_equal :okay, j.perform_now

    # => fail
    action = nil
    BaseJob.retry_on Retry, attempts: 1
    BaseJob.on_retries_exhausted{ action = :retry_parent_class }
    refute_equal :okay, RetryableJob.perform_now
    assert_equal :retry_parent_class, action

    action = nil
    BaseJob.retry_on(Retry, attempts: 1){ action = :retry }
    refute_equal :okay, RetryableJob.perform_now
    assert_equal :retry, action

    action = nil
    RetryableJob.retries_exhausted_handler = ->{ action = :retry_jobclass }
    refute_equal :okay, RetryableJob.perform_now
    assert_equal :retry, action
  end

end
