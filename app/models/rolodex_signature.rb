class RolodexSignature < ActiveRecord::Base

  has_many :rolodex_signature_entities
  belongs_to :entities,      class_name: "Entity",    foreign_key: "EntityID",  primary_key: "entity_id"
  has_one :entity,           class_name: "Entity",    foreign_key: "EntityID",  primary_key: "entity_id"
  has_one :update_employee,  class_name: "Employee",  foreign_key: "ID",        primary_key: "updated_by"
  has_one :file_doc_entities

  def add_children?
    self.rolodex_signature_entities.count <= 10
  end

  def generate_notary_text
    parent = self.rolodex_signature_entities.where("parent_id = 0").first
    return parent.name if self.rolodex_signature_entities.where("parent_id = #{parent.id}").first == nil

      type = parent.type.blank? ? self.entity.IndCorp : parent.type
    case type
    when "Corporation"
      notary = "#{get_block_notary(parent, "Corporation1")}, who being by me duly sworn, did say that "
      notary += "#{get_block_notary(parent, "Corporation2")}, of #{parent.name.gsub(/\r?\n/, " ")} and that said instrument was signed in behalf of said corporation by authority of its by-laws (or by a resolution of its board of directors) and said "
      notary += "#{get_block_notary(parent, "Corporation3")} duly acknowledged to me that said corporation executed the same and that the seal affixed is the seal of said corporation"
    when "LLC"
      notary = "#{get_block_notary(parent, "Corporation1")}, who being by me duly sworn, did say that "
      notary += "#{get_block_notary(parent, "Corporation2")} "
      notary += "#{get_block_notary(parent, "LLC")}"
    else
      notary = get_block_notary(parent, type)
    end
    notary
  end

  def get_block_notary(parent, type = nil, leaf = nil, split = [])
    return "" if split.include?(parent.id)

    parent_value = ""
    child_value = ""

    if self.rolodex_signature_entities.where("parent_id = #{parent.id}").first == nil
      return "" if leaf != nil && parent != leaf

      case type
      when "Corporation1"
        return "#{parent.name.gsub(/\r?\n/, " ") rescue 'NULL'}"
      when "Corporation2"
        return "the said #{parent.name.gsub(/\r?\n/, " ") rescue 'NULL'}#{", is the #{parent.title}" if parent.title != nil}"
      when "Corporation3"
        return "#{parent.name.gsub(/\r?\n/, " ") rescue 'NULL'}"
      when "LLC"
        return "#{parent.name.gsub(/\r?\n/, " ") rescue 'NULL'}"
      when "Trust"
        return "#{parent.name.gsub(/\r?\n/, " ") rescue 'NULL'}"
      else
        return "#{parent.name.gsub(/\r?\n/, " ") rescue 'NULL'}#{", #{parent.title}" if parent.title != nil}"
      end
    else
      self.rolodex_signature_entities.where("parent_id = #{parent.id}").order("sort_order ASC").each do |child|
        child_value = ""
        if parent_value == ""
          child_value = get_block_notary(child, type)
        else
          result = get_block_notary(child, type)
          if result != ""
            child_value +=  " and #{result}"
          end
        end

        unless child_value == "" || (parent.parent_id != 0 && type == "Corporation2")
          parent_value += "#{child_value}"
        end
      end

      if parent.parent_id == 0 && parent_value != ""
        case type
        when "Corporation2"
          parent_value += "#{child_value} of #{parent.name.gsub(/\r?\n/, " ") rescue 'NULL'}#{", is the #{parent.title}" if parent.title != nil }"
        when "LLC"
          parent_value = " of #{parent.name.gsub(/\r?\n/, " ")}, the Limited Liability Company that executed the herein instrument and acknowledged the instrument to be the free and voluntary act and deed of the Limited Liability Company, by authority of statute, its articles of organization or its operating agreement, for the uses and purposes herein mentioned, and on oath stated that they are authorized to execute this instrument on behalf of the Limited Liability Company"
        when "Partnership"
          parent_value += " General Partner(s) of #{parent.name.gsub(/\r?\n/, " ")}, the signer(s) of the within instrument, who duly acknowledge to me that they executed the same for and in behalf of said partnership"
        when "Trust"
          parent_value += ", Trustee(s) of #{parent.name.gsub(/\r?\n/, " ")}, the signer(s) of the above agreement who duly acknowledge to me that they executed the same"
        else
          unless type.include?("Corporation")
            parent_value += " of #{parent.name.gsub(/\r?\n/, " ") rescue 'NULL'}#{", #{parent.title}" if parent.title != nil }, the signer(s) of the above agreement who duly acknowledge to me that they executed the same"
          end
        end
      elsif parent_value != ""
        parent_value += " of #{parent.name.gsub(/\r?\n/, " ") rescue 'NULL'}#{", #{parent.title}" if parent.title != nil }"
      end
    end
    parent_value
  end
end
