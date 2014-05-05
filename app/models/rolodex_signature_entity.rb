class RolodexSignatureEntity < ActiveRecord::Base

  belongs_to :rolodex_signature
  has_one :rolodex_signature_entity_type, foreign_key: "id",       primary_key: "rolodex_signature_entity_type_id"
  has_one :entity,                        foreign_key: "EntityID", primary_key: "entity_id"

  def parent_type_id
    RolodexSignatureEntity.find(self.parent_id).rolodex_signature_entity_type_id
  end

  def type
    self.rolodex_signature_entity_type.blank? ? "" : self.rolodex_signature_entity_type.name
  end

  def margin
    c = -1
    parent = RolodexSignatureEntity.where("id = #{self.parent_id}").first

    while c < 11
      c += 1
      if parent == nil
        break
      else
        parent = RolodexSignatureEntity.where("id = #{parent.parent_id}").first
      end
    end

    return c * 10
  end

  def add_signature?
  	RolodexSignatureEntity.where("parent_id = #{self.id} and relationship != 'signature' ").first == nil
  end

  def generate_notary_text
    signature = self.rolodex_signature
    parent = signature.rolodex_signature_entities.where("parent_id = 0").first
    result = ""
    type = parent.type.blank? ? parent.entity.IndCorp : parent.type
    case type
    when "Corporation"
      starter = signature.get_block_notary(parent, "Corporation1", self)
      if starter != ""
        result = "#{starter}, who being by me duly sworn, did say that asdf"
        result += "#{signature.get_block_notary(parent, "Corporation2", self)}, of #{parent.name.gsub(/\r?\n/, " ")} and that said instrument was signed in behalf of said corporation by authority of its by-laws (or by a resolution of its board of directors) and said "
        result += "#{signature.get_block_notary(parent, "Corporation3", self)} duly acknowledged to me that said corporation executed the same and that the seal affixed is the seal of said corporation"
      end
    when "LLC"
      starter = signature.get_block_notary(parent, "Corporation1", self)
      if starter != ""
        result = "#{starter}, who being by me duly sworn, did say that "
        result += "#{signature.get_block_notary(parent, "Corporation2", self)} "
        result += "#{signature.get_block_notary(parent, "LLC", self)}"
      end
    else
      result = signature.get_block_notary(parent, type, self)
    end
    result
  end
end
