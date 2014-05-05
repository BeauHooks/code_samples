class Type < DisburseBase
  self.table_name  = "tblType"
  self.primary_key = "TypeID"

  belongs_to :receipts

  def name
    self.Receipted_Type
  end
end
