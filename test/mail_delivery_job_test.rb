require "test_helper"

class MailDeliveryJobTest < ActiveJob::TestCase

  MDJ = ActionMailer::MailDeliveryJob

  setup do
    MDJ.rescue_pro_rules = {}
  end

  test "passthrough unregistered exception" do
    ContactMailer.contact.deliver_later
    assert_raises Net::OpenTimeout do
      perform_enqueued_jobs only: MDJ
    end
  end

  test "handle registered exception on job" do
    MDJ.discard_on Net::OpenTimeout
    ContactMailer.contact.deliver_later

    action = nil
    MDJ.discard_on(Net::OpenTimeout){ action = :discard }
    assert_nothing_raised do
      perform_enqueued_jobs only: MDJ
    end
    assert_equal :discard, action
  end

end
