class RolodexSignatureEntityType < ActiveRecord::Base

  has_many   :rolodex_signature_entity_titles
  belongs_to :rolodex_signature_entity

end
