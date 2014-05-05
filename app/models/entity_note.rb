class EntityNote < ActiveRecord::Base
  self.table_name  = "tblEntityNotes"
  self.primary_key = "ID"

  after_save :update_entity_last_modified

  belongs_to :entity,                             foreign_key: "EntityID",         primary_key: "EntityID"

  # Employee Action-Tracking Relationships
  belongs_to :taken_by,   class_name: "Employee", foreign_key: "TakenBy",          primary_key: "ID"
  belongs_to :tickled_by, class_name: "Employee", foreign_key: "TickleEmployeeID", primary_key: "ID"

  def self.by_private(show_private, user_id)
    if show_private
      all
    else
      where("IsPrivate = 0 OR TakenBy = #{user_id}")
    end
  end

  def update_entity_last_modified
    self.entity.update_last_modified
  end

  def note_from
    if self.taken_by != nil
      self.taken_by.FullName
    else
      ""
    end
  end

  def note_to
    if self.tickled_by != nil
      self.tickled_by.FullName
    else
      ""
    end
  end

  def note_date
    if self.NoteDT != nil
      self.NoteDT.to_formatted_s(:standard)
    else
      ""
    end
  end

end
