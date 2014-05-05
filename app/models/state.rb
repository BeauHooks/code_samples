class State < StatisticsBase
  self.table_name  = "tblStates"
  self.primary_key = "ID"

  has_many :counties, foreign_key: "StateID", primary_key: "CountyID", order: "CountyName"

  # Return any and all regions (of any version) that completely contain as
  # a superset all counties within this state. This method only knows about
  # counties that are entered in the database so this may logically be
  # incorrect if you haven't entered the entire state's set of counties into
  # the databse. However, this may be a desired side-effect too.
  #
  # Returns an empty array if no matching regions found.
  #
  def regions
    Region.find_all_supersets(county_ids)
  end

  # Return any and all regions (of any version) that overlaps any part of the
  # state. Returns an empty array if no matching regions found.
  #
  def all_regions
    Region.find_all_intersecting(county_ids)
  end

  # Return any and all regions (of any version) that are completely conained
  # as a subset in the set of counties within this state. Returns an empty
  # array if no matching regions found
  #
  def contained_regions
    Region.find_all_subsets(county_ids)
  end

end
