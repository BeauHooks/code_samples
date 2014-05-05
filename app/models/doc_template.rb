class DocTemplate < ActiveRecord::Base

	has_many   :doc_template_versions
	has_many   :doc_group_templates
	belongs_to :county, foreign_key: "county_id", primary_key: "CountyID"

end
