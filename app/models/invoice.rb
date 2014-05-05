class Invoice < InvoiceBase
  self.table_name   = "tblInvoice"
  self.primary_key  = "InvoiceID"

  belongs_to :index,     foreign_key: "Fileid",              primary_key: "FileID"
  belongs_to :employee,  foreign_key: "InvoiceEmployeeID",   primary_key: "ID"

end
