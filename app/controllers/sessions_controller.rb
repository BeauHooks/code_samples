class SessionsController < Devise::SessionsController
  def create
    super
    response.headers['X-CSRF-Token'] = form_authenticity_token
  end
end