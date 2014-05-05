class FileDocEntitySignature < ActiveRecord::Base

  belongs_to :file_doc_entity, foreign_key: "doc_entity_id", primary_key: "id"

end
