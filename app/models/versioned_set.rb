class VersionedSet < ActiveRecord::Base

  has_many :calc_versions
  belongs_to :created_by, class_name: "Employee", foreign_key: "created_by", primary_key: "ID"
  belongs_to :updated_by, class_name: "Employee", foreign_key: "updated_by", primary_key: "ID"

end
