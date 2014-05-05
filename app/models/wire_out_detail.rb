class WireOutDetail < DisburseBase
  self.table_name  	= "tblWireOutDetail"
  self.primary_key 	= "ID"

  belongs_to :wire, class_name: 'Check', foreign_key: "WireID", primary_key: "ID"

end
