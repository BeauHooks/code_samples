class SitePreferenceOption < ActiveRecord::Base
  before_destroy :remove_user_preferences

  has_many :users, through: :user_preferences
  belongs_to :site_preference
  belongs_to :default_option, class_name: 'SitePreferenceOption', foreign_key: 'default', primary_key: 'id'

  def default?
    self.site_preference.default_option == self
  end

  def remove_user_preferences
  	UserPreference.where("name = '#{self.site_preference.name}' AND value = '#{self.setting}' ").each do |usr_pref|
  	  usr_pref.destroy
  	end
  end
end
