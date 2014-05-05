class Recipient < EmailArchiveBase

  belongs_to :message
  belongs_to :employee, primary_key: 'ID'
  belongs_to :entity,   primary_key: 'EntityID'

end
