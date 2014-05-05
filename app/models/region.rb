class Region < ActiveRecord::Base
  require 'set'

  belongs_to :calc_version, :foreign_key => :version_id, :primary_key => :id

  # Employee Action-Tracking Relationships
  belongs_to :created_by, :class_name => "Employee", :foreign_key => "created_by", :primary_key => "ID"
  belongs_to :updated_by, :class_name => "Employee", :foreign_key => "updated_by", :primary_key => "ID"

  # Reference to all the counties that comprise this region
  has_and_belongs_to_many :counties, :join_table => "regions_counties" # Join table in filetrak, has no Model and no migration

  # Return a list of all regions that, when treated as a set of counties, is a
  # superset of the provided list of counties. The provided list of counties
  # should be an array of county ids. If no regions match, an empty array is
  # returned.
  #
  def self.find_all_supersets(county_ids)
    all.reject do |r|
      !r.county_ids.to_set.superset?(county_ids.to_set)
    end
  end

  # Return a list of all regions that, when treated as a set of counties,
  # interects the set of counties defined by the list provided. The list should
  # be an array of county ids. If no regions match, an empty array is returned.
  #
  def self.find_all_intersecting(county_ids)
    all.reject do |r|
      (r.county_ids.to_set & county_ids.to_set).empty?
    end
  end

  # Return a list of all regions that, when treated as a set of counties, is a
  # subset of the provided list of counties. The provided list of counties
  # should be an array of county ids. If no regions match, an empty array is
  # returned.
  #
  def self.find_all_subsets(county_ids)
    all.reject do |r|
      !r.county_ids.to_set.subset?(county_ids.to_set)
    end
  end
end
