class EntitySignature < ActiveRecord::Base
  self.table_name  = "tblEntitySignatures"
  self.primary_key = "UserSigID"

  has_many   :entity_notaries, class_name: "EntityNotary", primary_key: "UserSigID", foreign_key: "UserSigID"
  belongs_to :entity,                                      primary_key: "EntityID",  foreign_key: "UserSigID"
  belongs_to :source,          class_name: "Entity",       primary_key: "EntityID",  foreign_key: "SourceEntityID"

  # Employee Action-Tracking Relationships
  belongs_to :entered_by,      class_name: "Employee",     primary_key: "ID",        foreign_key: "EnteredBy"

  # Cool ARel-like syntax courtesy of the meta_where gem
  def self.name_includes(pattern)
    pattern = "%#{pattern}" unless pattern.first == "%"
    pattern = "#{pattern}%" unless pattern.last  == "%"
    where(
      :FirstName.matches  % pattern |
      :MiddleName.matches % pattern |
      :LastName.matches   % pattern |
      :UserSig.matches    % pattern |
      :SearchName.matches % pattern
    )
  end

  def signature
    if self.UserSig != nil && self.Capacity != nil
      "#{self.UserSig}, #{self.Capacity}"
    elsif self.UserSig != nil
      self.UserSig
    elsif self.FirstName != nil && self.MiddleName != nil && self.LastName != nil
      "#{self.FirstName} #{self.MiddleName} #{self.LastName}"
    elsif self.FirstName != nil && self.LastName != nil
      "#{self.FirstName} #{self.LastName}"
    elsif self.FirstName != nil
      "#{self.FirstName}"
    elsif self.LastName != nil
      "#{self.LastName}"
    elsif self.UserEntity != nil
      "#{self.UserEntity}"
    else
      ""
    end
  end
end
