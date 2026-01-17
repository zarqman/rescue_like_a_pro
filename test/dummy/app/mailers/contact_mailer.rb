class ContactMailer < ApplicationMailer
  def contact
    raise Net::OpenTimeout # simulate error reaching smtp server
  end
end