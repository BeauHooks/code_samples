class ScopeUserPreference < UserPreference

  def self.for_object(object)
    @object = object
    self
  end

  def self.object_scoped
    unscoped.where(objects_type: @object.class.base_class.to_s, objects_id: @object.id)
  end
end