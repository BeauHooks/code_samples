class SitePreference < ActiveRecord::Base

  scope :navigation, where(category: 'navigation')
  scope :style, where(category: 'style')

  has_many :site_preference_options, dependent: :destroy
  has_many :user_preferences
  has_one :default_option, class_name: 'SitePreferenceOption', foreign_key: 'id', primary_key: 'default'

  accepts_nested_attributes_for :site_preference_options, allow_destroy: true

  validates :name, presence: true, uniqueness: true
  validates :question, presence: true
  validates :category, presence: true

end
