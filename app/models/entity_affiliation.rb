class EntityAffiliation < ActiveRecord::Base
  self.table_name  = "tblEntityAffiliations"
  self.primary_key = "ID"

  after_save :update_entity_last_modified

  belongs_to :entity_1,   class_name: "Entity",   foreign_key: "EntityID1",  primary_key: "EntityID"
  belongs_to :entity_2,   class_name: "Entity",   foreign_key: "EntityID2",  primary_key: "EntityID"
  belongs_to :contact_1,  class_name: "Entity",   foreign_key: "ContactID1", primary_key: "EntityID"
  belongs_to :contact_2,  class_name: "Entity",   foreign_key: "ContactID2", primary_key: "EntityID"

  # Employee Action-Tracking Relationships
  belongs_to :entered_by, class_name: "Employee", foreign_key: "EnteredBy",  primary_key: "ID"

  def update_entity_last_modified
    self.entity_1.update_last_modified unless self.entity_1.nil?
    self.entity_2.update_last_modified unless self.entity_2.nil?
    self.contact_1.update_last_modified unless self.contact_1.nil?
    self.contact_2.update_last_modified unless self.contact_2.nil?
  end

  def make_primary(entity_id)
    entity = Entity.find(entity_id)

    entity.affiliations_as_entity_1.each do |affiliation|
      if self.ID == affiliation.ID
        affiliation.Primary1 = -1
        entity.update_attributes(primary_affiliation_id: affiliation.EntityID2, primary_affiliation_name: affiliation.entity_2.FullName)
      else
        affiliation.Primary1 = 0
      end
      affiliation.save!
    end

    entity.affiliations_as_entity_2.each do |affiliation|
      if self.ID == affiliation.ID
        affiliation.Primary2 = -1
        entity.update_attributes(primary_affiliation_id: affiliation.EntityID1, primary_affiliation_name: affiliation.entity_1.FullName)
      else
        affiliation.Primary2 = 0
      end
      affiliation.save!
    end
  end
end
