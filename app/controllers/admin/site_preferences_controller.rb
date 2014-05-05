class Admin::SitePreferencesController < ApplicationController
  def index
  	@preferences = SitePreference.find :all
  end

  def show
  	@preference = SitePreference.find params[:id]
  end

  def edit
  	@preference = SitePreference.find(params[:id])
  	@preference.update_attributes(params[:site_preference])

  	respond_to do |format|
  		format.js {render "admin/site_preferences/update"}
  	end
  end

  def create
  	preference = SitePreference.create(params[:site_preference])
  	option = SitePreferenceOption.create(site_preference_id: preference.id, description: "", setting: "")
  	preference.update_attributes(default: option.id)
  	@preference = SitePreference.find preference.id
  end

  def update
  	@preference = SitePreference.find(params[:id])
  	@preference.update_attributes(params[:preference])
  end

  def destroy
  	SitePreference.find(params[:id]).destroy
  	render js: "
  		if($('#preferences_list').find('.active_row').length == 0){
  			$('#preferences_list tr:first').click();
  		}
  	"
  end
end