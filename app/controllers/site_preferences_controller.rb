class SitePreferencesController < ApplicationController
  respond_to :html, :json, :js
  before_filter :page_name

  def index
    @site_preferences = SitePreference.all
  end

  def new
    @site_preference = SitePreference.new
    @site_preference.site_preference_options.build
    @site_preference
  end

  def edit
    @site_preference = SitePreference.find(params[:id])
  end

  def create
    @site_preference = SitePreference.create(params[:site_preference])
    @site_preference.save
  end

  def update
    @site_preference = SitePreference.find(params[:id])
    @site_preference.update_attributes(params[:site_preference])
    render "admin/preference_list"
  end

  def set_preference
    site_preference_option = SitePreferenceOption.find(params[:id])
    current_user.users_preferences[site_preference_option.site_preference.name] = site_preference_option.setting
    render nothing: true unless site_preference_option.site_preference.category == "style"
  end

  def set_user_preference
    site_preference_option = SitePreferenceOption.find(params[:site_preference_id])
    user = User.find(params[:user_id])
    UserPreference.destroy_all(user_id: user.id, site_preference_id: site_preference_option.site_preference_id)
    pref = user.user_preferences.create(site_preference_option: site_preference_option, site_preference: site_preference_option.site_preference)
    pref.save
    render :nothing => true
  end

  def destroy
    @site_preference = SitePreference.find(params[:id])
    @site_preference.destroy
    render Rails.application.routes.recognize_path(request.referer)
  end

  private

    def page_name
      @page_name = "Site Preferences"
    end

end