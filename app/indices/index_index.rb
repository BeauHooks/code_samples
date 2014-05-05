ThinkingSphinx::Index.define :index, with: :active_record do
  indexes 'DisplayFileID', :as => :displayfileid
  indexes 'Buyer1Name'
  indexes 'Buyer2Name'
  indexes 'Seller1Name'
  indexes 'Seller2Name'
  indexes 'PROut'
  indexes 'Recorded'
  indexes 'PolicyOut'
  indexes 'CloserName'
  indexes 'TaxID1'
  indexes 'Address1'
  has 'IsClosed',          :as => :isclosed, :type => :boolean
  has 'Opened',            :as => :opened,   :type => :timestamp, :sortable => true
  has 'Company',           :as => :company,  :type => :integer
  has 'DisplayFileID',     :as => :file_id,  :type => :integer,  :sortable => true
  set_property :delta => true
end