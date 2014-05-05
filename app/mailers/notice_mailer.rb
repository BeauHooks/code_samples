class NoticeMailer < ActionMailer::Base
  default from: "FTWeb Feedback <ftwebfeedback@efusionpro.com>"

  def send_message(user, subject, message, to_name, to_email)
  	@user = user
  	@to_name = to_name
    @message = message.gsub("\n", "<br />")
    mail(to: "#{to_name.gsub(/[^A-Za-z0-9\s]/, "")} <#{to_email}>", subject: subject, reply_to: user.email)
  end

  def notification(user, subject, message, to_name, to_email)
  	@user = user
  	@to_name = to_name
    @message = message.gsub("\n", "<br />")
    mail(to: "#{to_name.gsub(/[^A-Za-z0-9\s]/, "")} <#{to_email}>", subject: subject, reply_to: user.email)
  end
end
