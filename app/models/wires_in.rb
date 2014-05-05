class WiresIn < DisburseBase
  self.table_name  = "tblWiresIn"
  self.primary_key = "ID"

  belongs_to :receipt, foreign_key: "ID", primary_key: "WireInID"

end
