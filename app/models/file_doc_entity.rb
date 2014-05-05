class FileDocEntity < ActiveRecord::Base

  belongs_to :index,                      foreign_key: "file_id",       primary_key: "FileID"
  belongs_to :entity,                     foreign_key: "entity_id",     primary_key: "EntityID"
  belongs_to :doc
  has_many   :file_doc_entity_signatures, foreign_key: "doc_entity_id", primary_key: "id", order: "sort_order"
  belongs_to :rolodex_signature

  delegate :name, to: :entity, prefix: false, allow_nil: true

  def normalize_tag(tag)
    tag.gsub!("*", "")
    tag.downcase
  end

  def self.get_value(order)
    value = FileDocEntity.where(tag: "#{tag}", doc_id: 0).last

    if value != nil
      FileDocEntity.where(tag: "#{tag}", doc_id: 0).last.value != nil ? value = FileDocEntity.where(tag: "#{tag}", doc_id: 0).last.value : value = ""
    else
      value = ""
    end

    if tag == "GRANTEE_COUNTY" || tag == "GRANTOR_COUNTY"
      case value
      when "4"
        value = "Washington"
      end
    end
    value
  end

  def self.active_entities(doc_id_list, tag)
    self.where("#{tag} AND is_active = 1 AND doc_id IN (#{doc_id_list.join(',')})").order("sort_order ASC")
  end

  def signature_block?
    if self.rolodex_signature_id.nil?
      false
    else
      true
    end
  end

  def signature_block
    self.rolodex_signature.block_text
  end

  # Get signatures helper method
  def signatures
    self.file_doc_entity_signatures.where("is_active = -1")
  end

  def generate_notary_text
    self.rolodex_signature.generate_notary_text
  end

   def entity_name
    return self.entity.nil? ? "" : self.entity.full_name
  end
end
