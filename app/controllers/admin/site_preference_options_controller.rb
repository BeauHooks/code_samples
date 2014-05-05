class Admin::SitePreferenceOptionsController < ApplicationController
  def create
    option = SitePreferenceOption.create(site_preference_id: params[:site_preference_id], description: params[:description], setting: params[:setting])
    if option.site_preference.default.blank?
      option.site_preference.update_attributes(default: option.id)
    end
    @option = SitePreferenceOption.find option.id
  end

  def update
    SitePreferenceOption.find(params[:id]).update_attributes(params[:option])
    render nothing: true
  end

  def destroy
    option = SitePreferenceOption.find params[:id]

    if option.site_preference.default == option.id.to_s
      render js: "$.post('application/flash_notice?title=Delete Error&notice=Cannot delete the default option of a preference.');"
      return
    end

    option.destroy
    render nothing: true
  end
end