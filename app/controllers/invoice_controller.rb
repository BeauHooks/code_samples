class InvoiceController < ApplicationController
	include ActionView::Helpers::NumberHelper

	def hud_fees
		@file = Index.find params[:file_id]
		@hud = Hud.find params[:hud_id]
		list = ["buyer", "seller"]

		@invoice = Invoice.find @hud.invoice_id rescue nil
		if @invoice == nil
			@invoice = create_invoice(list.count)
		end

		list.each do |side|
			HudInvoiceDefaultFee.all.each do |fee|
				if HudInvoice.where("hud_id = #{@hud.id} AND side = '#{side}' AND hud_invoice_default_fee_id = #{fee.id}").first == nil
					create_hud_invoice(side, fee)
				end
			end
		end

		@buyer_fees = HudInvoice.find(:all, conditions: ["hud_invoices.hud_id = #{@hud.id} AND hud_invoices.side='buyer' "], include: [:hud_invoice_default_fee], order: ["hud_invoice_default_fees.id ASC"])
		@seller_fees = HudInvoice.find(:all, conditions: ["hud_invoices.hud_id = #{@hud.id} AND hud_invoices.side='seller' "], include: [:hud_invoice_default_fee], order: ["hud_invoice_default_fees.id ASC"])
	end

	def update_hud_invoice
		@hud = Hud.find params[:hud_id]
		invoice = Invoice.find params[:invoice_id]
		@lines = []

		if params[:buyer]
			params[:buyer].each do |fee|
				item = HudInvoice.find fee[0]
				item.units = fee[1][:units]
				item.price = fee[1][:price]
				item.total = (item.units || 0) * (item.price || 0.0)
				item.save
			end
		end

		if params[:seller]
			params[:seller].each do |fee|
				item = HudInvoice.find fee[0]
				item.units = fee[1][:units]
				item.price = fee[1][:price]
				item.total = (item.units || 0) * (item.price || 0.0)
				item.save
			end
		end

		# Update Hud From Fees
		case @hud.hud_type
		when "standard"
			lender_policy = @hud.hud_lines.where("number = 1104").first.amount.to_f rescue 0.0
			invoice.LenderPol = lender_policy
			invoice.OwnerPol = @hud.hud_lines.where("number = 1103").first.borrower_amount.to_f rescue 0.0

			line = @hud.hud_lines.where("number = 1202").first
			line.deed_amount = HudInvoice.sum(:total, conditions: ["hud_invoices.hud_id = #{@hud.id} AND hud_invoice_default_fees.label = 'Recording Fees - WD' AND hud_invoices.side = 'buyer' "], include: [:hud_invoice_default_fee]).to_f + lender_policy
			line.mortgage_amount = HudInvoice.sum(:total, conditions: ["hud_invoices.hud_id = #{@hud.id} AND hud_invoice_default_fees.label = 'Recording Fees - TD' AND hud_invoices.side = 'buyer' "], include: [:hud_invoice_default_fee]).to_f + lender_policy
			line.releases_amount = HudInvoice.sum(:total, conditions: ["hud_invoices.hud_id = #{@hud.id} AND hud_invoice_default_fees.label = 'Recording Fees - Recon' AND hud_invoices.side = 'buyer' "], include: [:hud_invoice_default_fee]).to_f + lender_policy
			line.seller_amount = HudInvoice.sum(:total, conditions: ["hud_invoices.hud_id = #{@hud.id} AND hud_invoice_default_fees.label = 'Recording Fees - Recon' AND hud_invoices.side = 'buyer' "], include: [:hud_invoice_default_fee]).to_f + lender_policy
			line.save
			@lines << line
			
			line = @hud.hud_lines.where("number = 1102").first
			line.amount = HudInvoice.sum(:total, conditions: ["hud_invoices.hud_id = #{@hud.id} AND hud_invoice_default_fees.invoice_column = 'ClosingFee' AND hud_invoices.side = 'buyer' "], include: [:hud_invoice_default_fee]).to_f
			line.seller_amount = HudInvoice.sum(:total, conditions: ["hud_invoices.hud_id = #{@hud.id} AND hud_invoice_default_fees.invoice_column = 'ClosingFee' AND hud_invoices.side = 'seller' "], include: [:hud_invoice_default_fee]).to_f
			line.save
			@lines << line

			line = @hud.hud_lines.where("number = 1101").first
			line.borrower_amount = HudInvoice.sum(:total, conditions: ["hud_invoices.hud_id = #{@hud.id} AND hud_invoice_default_fees.invoice_column IN ('ClosingFee', 'FedEx', 'DocPrep') AND hud_invoices.side = 'buyer' "], include: [:hud_invoice_default_fee]).to_f + lender_policy
			line.seller_amount = HudInvoice.sum(:total, conditions: ["hud_invoices.hud_id = #{@hud.id} AND hud_invoice_default_fees.invoice_column IN ('FedEx', 'DocPrep') AND hud_invoices.side = 'seller' "], include: [:hud_invoice_default_fee]).to_f
			line.save
			@lines << line

			line = @hud.hud_lines.where("number = 1201").first
			line.save
			@lines << line

		when "in-house"
			fees = ["RecFee", "ClosingFee", "EscrowCol", "FedEx", "DocPrep"]
			invoice.LenderPol = @hud.hud_lines.where("number = 3004").first.charges.to_f rescue 0.0
			invoice.OwnerPol = @hud.hud_lines.where("number = 4004").first.charges.to_f rescue 0.0
			
			n = 3005
			fees.each do |fee|
				line = @hud.hud_lines.where("number = #{n}").first
				line.charges = HudInvoice.sum(:total, conditions: ["hud_invoices.hud_id = #{@hud.id} AND hud_invoice_default_fees.invoice_column = '#{fee}' AND hud_invoices.side = 'buyer' "], include: [:hud_invoice_default_fee]).to_f
				line.save
				@lines << line
				n += 1
			end

			n = 4005
			fees.each do |fee|
				line = @hud.hud_lines.where("number = #{n}").first
				line.charges = HudInvoice.sum(:total, conditions: ["hud_invoices.hud_id = #{@hud.id} AND hud_invoice_default_fees.invoice_column = '#{fee}' AND hud_invoices.side = 'seller' "], include: [:hud_invoice_default_fee]).to_f
				line.save
				@lines << line
				n += 1
			end

		when "loan-in-house"
			fees = ["RecFee", "ClosingFee", "EscrowCol", "FedEx", "DocPrep"]
			invoice.LenderPol = @hud.hud_lines.where("number = 5004").first.charges.to_f rescue 0.0
			
			n = 5005
			fees.each do |fee|
				line = @hud.hud_lines.where("number = #{n}").first
				line.charges = HudInvoice.sum(:total, conditions: ["hud_invoices.hud_id = #{@hud.id} AND hud_invoice_default_fees.invoice_column = '#{fee}' AND hud_invoices.side = 'buyer' "], include: [:hud_invoice_default_fee]).to_f
				line.save
				@lines << line
				n += 1
			end
		end

		respond_to do |format|
      format.js { render "invoice/update_view"}
    end

		# Update Invoice From Fees
		total = 0.0
		fields = ["ClosingFee", "Endorsements", "DocPrep", "ExchangeFee", "FedEx", "EscrowCol", "Recon", "RecFee", "LimRpt", "CancelFee", "Forclose", "Lit", "PlatFee", "LenderPol", "OwnerPol", "JuniorPol", "TransferTax", "CPLEndorsement"]
		#HudInvoiceDefaultFee.select("invoice_column").group("invoice_column") 

	  fields.each do |field|
	  	value = HudInvoice.sum(:total, conditions: ["hud_invoices.invoice_id = #{invoice.InvoiceID} AND hud_invoice_default_fees.invoice_column = '#{field}' "], include: [:hud_invoice_default_fee]).to_f
	  	
	  	if value != nil && value > 0 
	  		total += value
	  		invoice.send("#{field}" + "=", value)
	  	else
	  		total += (invoice.send("#{field}".to_sym) || 0.0)
	  	end
	  end

	  invoice.InvoiceTotal = total
		invoice.InvoiceBalance = invoice.InvoiceTotal
		invoice.save
	end

	def update
		@invoice = Invoice.find params[:id]
		fields = ["ClosingFee", "Endorsements", "DocPrep", "ExchangeFee", "FedEx", "EscrowCol", 
	    "Recon", "RecFee", "LimRpt", "CancelFee", "Forclose", "Lit", "PlatFee", "LenderPol", "OwnerPol", "JuniorPol", "TransferTax", "CPLEndorsement"]

		if @invoice.InvDate != nil
			value = @invoice.send("#{params[:field]}".to_sym)

			if fields.include?(params[:field])
				value = number_to_currency(value, unit: '')
			end

			render js: "$('div#invoice_wrapper ##{params[:field]}').val('#{value}'); addToQueue('cannot_edit_invoice', 'application/flash_notice?notice=Invoice cannot be edited after it has been assigned an invoice date.');"
			return
		end

		if params[:field]
			if params[:field]  == "InvDate"
				split_date = params[:value].split("/")
	      value = "#{split_date[2]}-#{split_date[0]}-#{split_date[1]}"
	      @invoice.InvDate = value
			else
				@invoice.send(params[:field] + "=", params[:value])
			end

	    if fields.include?(params[:field])
				total = 0.0
				fields.each do|field|
					total += (@invoice.send("#{field}".to_sym) || 0.0)
				end

				@invoice.InvoiceTotal = total
				@invoice.InvoiceBalance = @invoice.InvoiceTotal
				@update_view = true
			end
			@invoice.save
		end
	end

	def set_invoice_date
		invoice = Invoice.find params[:id]
		invoice.InvDate = Time.now.to_s(:db)
		invoice.save

		render js: "if($('#all_docs .active_row').html() != undefined){row = $('#all_docs .active_row'); $(row).removeClass('active_row'); $(row).click();}"
	end

	private

	def create_hud_invoice(side, fee)
		record = HudInvoice.new
		record.hud_id = @hud.id
		record.invoice_id = @invoice.id
		record.side = side
		record.hud_invoice_default_fee_id = fee.id
		record.price = fee.amount

		case fee.invoice_column
		when "ClosingFee"
			record.units = 1
			record.total = record.units * record.price
		end 

		record.created_by = current_user.employee_id
		record.created_at = Time.now.to_s(:db)
		record.updated_by = current_user.employee_id
		record.updated_at = Time.now.to_s(:db)
		record.save
	end

	def create_invoice(sides)
		time = Time.now.to_s(:db)
		template = DocTemplate.where(" short_name = 'INV' ").first

		doc                       = Doc.new
    doc.file_id               = @file.FileID
    doc.company_id            = @file.Company
    doc.doc_template_id       = template.id
    doc.doc_signature_type_id = template.doc_template_versions.where("version = #{template.current_version}").first.doc_signature_type_id
    doc.doc_template_version  = template.current_version
    doc.template_text         = template.doc_template_versions.where("version = #{template.current_version}").first.template_text
    doc.created_by            = current_user.employee_id
    doc.updated_by            = current_user.employee_id
    doc.updated_at            = time
    doc.created_at            = time

    doc.description = Company.find(@file.Company).CompanyName

    invoice = Invoice.new
    invoice.from_ftweb = -1 # This is set to show that invoice is from new system for accounting
    invoice.Fileid = @file.FileID
    invoice.DisplayFileID = @file.DisplayFileID
    invoice.DeliverTo = "Accounting"
    invoice.InvoiceEmployeeID = current_user.employee_id
    invoice.EmployeeInitials = "#{current_user.first_name[0]}#{current_user.last_name[0]}"
    invoice.CompanyID = @file.Company
    invoice.EnteredBy = current_user.employee_id
    invoice.EnteredDT = Time.now.to_s(:db)
    invoice.EntityID = 0
    invoice.ClosingFee = sides * 295
    invoice.LenderPol = @hud.hud_lines.where("number = 1104").first.amount.to_f rescue 0.0

    owner = @hud.hud_lines.where("number = 1103").first
    invoice.OwnerPol = owner.borrower_amount.to_f + owner.seller_amount.to_f + owner.amount.to_f rescue 0.0

    invoice.Notes = "Created from HUD 1100 Fees. Changes made here WILL NOT affect the HUD nor the fees from which this invoice was generated. Changes made from the hud fees view will overwrite changes made here."

    if @file.TransactionDescription1 == ("Refinance" || "Construction Loan")
      invoice.Owner = @file.file_doc_fields.where("doc_id = 0 AND tag = 'GRANTEE_NAMES' ").first.value || nil
    else
      invoice.Owner = @file.file_doc_fields.where("doc_id = 0 AND tag = 'GRANTOR_NAMES' ").first.value || nil
    end

    invoice.PropertyID = @file.file_doc_fields.where("doc_id = 0 AND tag = 'PROPERTY_ADDRESS' ").first.value || nil

    invoice.save
    doc.invoice_id = invoice.id
    doc.save

	  return invoice
	end
end
