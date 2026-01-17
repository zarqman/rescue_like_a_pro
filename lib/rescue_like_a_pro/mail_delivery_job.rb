module RescueLikeAPro::MailDeliveryJob
  extend ActiveSupport::Concern

  def handle_exception_with_mailer_class(exception)
    super
  rescue Exception
    rescue_like_a_pro $!
  end

end
