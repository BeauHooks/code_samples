class FileEmployee < ActiveRecord::Base
  self.table_name  = "tblFileEmployees"
  self.primary_key = "ID"

  attr_default :Position, ""

  CLOSER_POSITIONS = [
    'Closer',
    'Closer - Both',
    'Closer - Loan',
    'Closer - Owner',
    'Closer - Buyer',
    'Closer - Seller'
  ].freeze

  scope :closers, :conditions => { :Position => CLOSER_POSITIONS }

  belongs_to :index,     foreign_key: "index_id",     primary_key: "ID"
  belongs_to :employee,  foreign_key: "EmployeeID", primary_key: "ID"

  before_save :update_dummy_time
  after_save :update_convienence_fields

  delegate :is_destroyable?, to: :index

  private

  def update_dummy_time
    self.DummyTime = Time.now.to_s(:db)
  end

  def update_convienence_fields
    file = self.index

    if self.is_active?
      if self.EmployeeID_changed? && self.Position.include?("Closer")
        file.CloserAssigned = self.EmployeeID
        file.CloserName = self.employee.FullName
      end

      if self.EmployeeID_changed? && self.Position.include?("Searcher")
        file.SearcherAssigned = self.EmployeeID
      end

      if self.Position_changed?
        if self.EmployeeID == file.CloserAssigned
          file.CloserAssigned = nil
          file.CloserName = nil
        elsif self.EmployeeID == file.SearcherAssigned
          file.SearcherAssigned = nil
        end

        if self.Position.include?("Closer")
          file.CloserAssigned = self.EmployeeID
          file.CloserName = self.employee.FullName
        elsif self.Position.include?("Searcher")
          file.SearcherAssigned = self.EmployeeID
        end

        if file.CloserAssigned.nil?
          closer = file.file_employees.where("Position LIKE 'Closer%'").first
          if !closer.nil?
            file.CloserAssigned = closer.EmployeeID
            file.CloserName = closer.employee.FullName
          end
        elsif file.SearcherAssigned.nil?
          searcher = file.file_employees.where("Position LIKE 'Searcher%'").first
          if !searcher.nil?
            file.SearcherAssigned = searcher.EmployeeID
          end
        end
      end
    else
      if self.EmployeeID == file.CloserAssigned
        file.CloserAssigned = nil
        file.CloserName = nil
      elsif self.EmployeeID == file.SearcherAssigned
        file.SearcherAssigned = nil
      end
    end
    # file.save!
  end
end