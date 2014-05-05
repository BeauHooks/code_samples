class UsersPreferencesController < ApplicationController
  def update
    current_user.users_preferences[params[:name]] = params[:value]
    render nothing: true
  end
end