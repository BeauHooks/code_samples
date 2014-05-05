class Doc < ActiveRecord::Base

  has_many   :file_doc_entities
  belongs_to :doc_signature_type
  belongs_to :doc_template
  belongs_to :hud
  belongs_to :settlement_statement
  belongs_to :invoice,                                      foreign_key: "invoice_id",     primary_key: "InvoiceID"
  belongs_to :filing1099,                                   foreign_key: "filing_1099_id", primary_key: "ID"
  belongs_to :index,                                        foreign_key: "file_id",        primary_key: "FileID"
  has_one    :update_employee, class_name: "Employee",      foreign_key: "ID",             primary_key: "updated_by"
  has_many   :file_doc_fields,                              foreign_key: "doc_id",         primary_key: "id"
  has_one    :doc_entity,      class_name: "FileDocEntity", foreign_key: "id",             primary_key: "doc_entity_id"

  def destroy
    self.update_column("is_active", 0)

    unless self.settlement_statement.blank?
      self.settlement_statement.payment_disbursements.each do |payment_disbursement|
        payment_disbursement.destroy
      end
    end
  end

  def doc_type
  	DocTemplate.find(self.doc_template_id).doc_type.description
  end

  def doc_type_shortname
  	DocTemplate.find(self.doc_template_id).doc_type.short_name
  end

  def has_update?
    template = DocTemplate.find(self.doc_template_id)
    current_version = template.current_version
    min_version = template.minimum_version

    if self.doc_template_version != current_version
      if self.doc_template_version != min_version
        version = template.doc_template_versions.where("version = #{min_version}").first

        self.doc_template_version = min_version
        self.template_text = version.template_text
        self.updated_by = version.created_by
        self.updated_at = Time.now.to_s(:db)
        self.save
        return false
      end
      true
    else
      false
    end
  end

  def has_active_entities?
    self.file_doc_entities.where("is_active = 1").count > 0
  end

  # Settlement Costs calculations
  def settlement_costs(sales_price)
    total = []
    case sales_price
    when 0..50000
      total << 150
    when 50001..200000
      total << 150
      total << (sales_price > 150000 ? 150000*0.001 : (sales_price - 50000)*0.001)
    when 200001..500000
      total << 150
      total << (sales_price > 150000 ? 150000*0.001 : (sales_price - 50000)*0.001)
      total << (sales_price > 500000 ? 300000*0.0005 : (sales_price - 200000)*0.0005)
    when 500001..1000000
      total << 150
      total << (sales_price > 150000 ? 150000*0.001 : (sales_price - 50000)*0.001)
      total << (sales_price > 500000 ? 300000*0.0005 : (sales_price - 200000)*0.0005)
      total << (sales_price > 1000000 ? 500000*0.0003 : (sales_price - 500000)*0.0003)
    else
      total << 150
      total << (sales_price > 150000 ? 150000*0.001 : (sales_price - 50000)*0.001)
      total << (sales_price > 500000 ? 300000*0.0005 : (sales_price - 200000)*0.0005)
      total << (sales_price > 1000000 ? 500000*0.0003 : (sales_price - 500000)*0.0003)
      total << (sales_price > 1000000 ? (sales_price - 1000000)*0.00025 : 0)
    end
    (total.sum/2).round
  end
end
