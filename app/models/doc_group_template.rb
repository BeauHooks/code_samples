class DocGroupTemplate < ActiveRecord::Base

  belongs_to :doc_group
  belongs_to :doc_template

end
