class FileEntity < ActiveRecord::Base
  self.table_name  = "tblFileEntities"
  self.primary_key = "ID"

  after_create   :add_to_entity_file_count
  before_destroy :subtract_from_entity_file_count, :remove_from_convienence_fields
  before_save    :update_related
  after_save     :update_convienence_fields

  belongs_to :index,                                 foreign_key: 'FileID',   primary_key: 'FileID'
  belongs_to :entity,                                foreign_key: 'EntityID', primary_key: 'EntityID'
  belongs_to :user_type, class_name: 'FileUserType', foreign_key: 'Position', primary_key: 'ID'
  belongs_to :lender,    class_name: 'Index',        inverse_of: :lenders
  belongs_to :borrower,  class_name: 'Index',        inverse_of: :borrowers

  default_scope where("`tblFileEntities`.`EntityID` IS NOT NULL OR `tblFileEntities`.`EntityID` != ''")

  def position
    self.user_type.nil? ? "" : self.user_type.TypeDescription
  end

  def add_to_entity_file_count
    self.entity.add_to_file_count
  end

  def subtract_from_entity_file_count
    self.entity.subtract_from_file_count
  end

  def update_related
    if self.NameCheckedBy_changed?
      self.NameCheckedDT = Time.now.to_s(:db)
    end
  end

  def name_checked_by
    Employee.find(self.NameCheckedBy).FullName rescue "NULL"
  end

  def first_phone
    self.entity.entity_contacts.phones_callable.first.Contact unless self.entity.entity_contacts.phones_callable.first.nil?
  end

  def first_fax
    self.entity.entity_contacts.fax.first.Contact unless self.entity.entity_contacts.fax.first.nil?
  end

  def entity_rules
    EntityRule.where("EntityID = #{self.entity.EntityID}") unless self.entity.nil?
  end

  def contacts
    self.entity.entity_contacts.where("ContactType = 'ADDRESS' ") unless self.entity.nil?
  end

  def entity_name
    name = self.entity.nil? ? "" : self.entity.name
  end

  def entity_fullname
    name = self.entity.nil? ? "" : self.entity.FullName
  end

  private

  def update_convienence_fields
    file = self.index

    case self.Position
    when 1 # Buyer
      if self.EntityID == file.try("Seller1")
        file.Seller1 = file.Seller2
        file.Seller1Name = file.Seller2Name
      elsif self.EntityID == file.try("Seller2")
        file.Seller2 = nil
        file.Seller2Name = nil
      elsif self.EntityID == file.try("Lender1")
        file.Lender1 = nil
      end

      old_buyer_1 = file.Buyer1
      old_buyer_1_name = file.Buyer1Name

      file.Buyer1 = self.EntityID
      file.Buyer1Name = self.entity.FullName

      file.Buyer2 = old_buyer_1
      file.Buyer2Name = old_buyer_1_name
    when 2 # Seller
      if self.EntityID == file.try("Buyer1")
        file.Buyer1 = file.Buyer2
        file.Buyer1Name = file.Buyer2Name
      elsif self.EntityID == file.try("Buyer2")
        file.Buyer2 = nil
        file.Buyer2Name = nil
      elsif self.EntityID == file.try("Lender1")
        file.Lender1 = nil
      end

      old_seller_1 = file.Seller1
      old_seller_1_name = file.Seller1Name

      file.Seller1 = self.EntityID
      file.Seller1Name = self.entity.FullName

      file.Seller2 = old_seller_1
      file.Seller2Name = old_seller_1_name
    when 3 # Lender
      if self.EntityID == file.try("Buyer1")
        file.Buyer1 = file.Buyer2
        file.Buyer1Name = file.Buyer2Name
      elsif self.EntityID == file.try("Buyer2")
        file.Buyer2 = nil
        file.Buyer2Name = nil
      elsif self.EntityID == file.try("Seller1")
        file.Seller1 = file.Seller2
        file.Seller1Name = file.Seller2Name
      elsif self.EntityID == file.try("Seller2")
        file.Seller2 = nil
        file.Seller2Name = nil
      end

      file.Lender1 = self.EntityID
    end
    file.save!
  end

  def remove_from_convienence_fields
    file = self.index

    case self.Position
    when 1 # Buyer
      if self.EntityID == file.try("Buyer1")
        file.Buyer1 = file.Buyer2
        file.Buyer1Name = file.Buyer2Name
      else
        file.Buyer2 = nil
        file.Buyer2Name = nil
      end
    when 2 # Seller
      if self.EntityID == file.try("Seller1")
        file.Seller1 = file.Seller2
        file.Seller1Name = file.Seller2Name
      else
        file.Seller2 = nil
        file.Seller2Name = nil
      end
    when 3 # Lender
      if self.EntityID == file.try("Lender1")
        file.Lender1 = nil
      end
    end
    file.save!
  end
end