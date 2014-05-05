class SecureDownloadMailer < ActionMailer::Base
  default from: "No Reply <no-reply@efusionpro.com>"

  def secure_download(to, from, subject, body)
    @body = body
    mail(to: to, from: from, subject: subject)
  end
end