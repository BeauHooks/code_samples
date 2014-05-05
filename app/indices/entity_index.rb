ThinkingSphinx::Index.define :entity, with: :active_record do
  indexes 'EntityID'
  indexes 'FirstName'
  indexes 'LastName'
  indexes 'FullName'
  indexes 'WorkPhone'
  indexes 'CellPhone'
  indexes 'primary_address'
  indexes 'primary_affiliation_name'
  has 'IsActive', as: :is_active, type: :boolean
  set_property :delta => true
end
