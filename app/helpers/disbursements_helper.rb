module DisbursementsHelper
  def get_hud_list
    huds = @file.docs.where("hud_id IS NOT NULL AND is_active = -1")
    hud_list = ""
    huds.each do |h|
      hud_list += "<option value='#{h.hud_id}'>#{h.description}</option>"
    end
    return hud_list.html_safe
  end

  def get_receipt_html
    html = render partial: "check_workings/receipt"
    style = open(Rails.root.join("app/assets/stylesheets/print/doc_print.css"), "rb").read
    html = "<style>#{style}</style>#{html}"
    margin_top    = '0.5in'
    margin_right  = '0.5in'
    margin_bottom = '0.5in'
    margin_left   = '0.5in'

    footer = ""
    header = ""

    pdf = PDFKit.new(html, {footer_html: ("#{footer}" if footer != ""), header_html: ("#{header}" if header != ""), title: "#{@file.DisplayFileID}", margin_top:"#{margin_top}", margin_right:"#{margin_right}", margin_bottom:"#{margin_bottom}", margin_left:"#{margin_left}"  }).to_pdf
    filename = random_string + ".pdf"
    path = File.expand_path(filename, Rails.root + "tmp/receipts/")
    file = File.new(path, "w+b")
    file.puts pdf.to_s
    file.close

    return filename
  end

  def get_disbursement_sheet_html
    html = render("check_workings/disbursement_sheet")
    style = open(Rails.root.join("app/assets/stylesheets/print/doc_print.css"), "rb").read
    html = "<style>#{style}</style>#{html}"
    margin_top    = '0.5in'
    margin_right  = '0.5in'
    margin_bottom = '0.5in'
    margin_left   = '0.5in'

    pdf = PDFKit.new(html, {orientation: "Landscape", title: "#{@file.DisplayFileID}", margin_top:"#{margin_top}", margin_right:"#{margin_right}", margin_bottom:"#{margin_bottom}", margin_left:"#{margin_left}"  }).to_pdf
    filename = random_string + ".pdf"
    path = File.expand_path(filename, Rails.root + "tmp/check_workings/")
    file = File.new(path, "w+b")
    file.puts pdf.to_s
    file.close

    return filename
  end

  def random_string(length=10)
    string   = ''
    chars    = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ123456789'
    length.times { |i| string << chars[rand(chars.length)] }
    string
  end

  def get_confirmation_html
    filename = random_string + ".pdf"
    path = File.expand_path(filename, Rails.root + "tmp/confirmation_images/")
    margin_top    = '0.5in'
    margin_right  = '0.5in'
    margin_bottom = '0.5in'
    margin_left   = '0.5in'

    footer = ""
    header = ""

    if @working.funds_type.to_s.downcase == "wire"
      case @file.Company
      when 101 || 103 || 106
        company_logo = "sutc_logo_color.jpg"
      when 102
        company_logo = "terra_logo_color.jpg"
      else
        company_logo = ""
      end

      html = render partial: "check_workings/confirmation", locals: {company_logo: company_logo, live: @working.check}
      pdf = PDFKit.new(html, {footer_html: ("#{footer}" if footer != ""), header_html: ("#{header}" if header != ""), margin_top:"#{margin_top}", margin_right:"#{margin_right}", margin_bottom:"#{margin_bottom}", margin_left:"#{margin_left}"  }).to_pdf

      file = File.new(path, "w+b")
      file.puts pdf.to_s
      file.close
    else
      number = @working.check.CheckNo
      folder = (number.to_i/1000).to_s.split(".")[0]
      @image_path = DriveMap.posix( ["K:", "CheckImages", @file.company.BankAccountNum, folder, number.to_s + ".tif"].join("\\") )
      result = `tiff2pdf -o #{path} #{@image_path}`
    end

    return filename
  end

  def get_memo_info(file)
    grantees, grantors, property = "", "", ""

    file.file_doc_fields.where("doc_id = 0 AND tag in ('GRANTEE_NAMES', 'GRANTOR_NAMES', 'FULL_PROPERTY_ADDRESS')").each do |field|
      case field.tag
      when "GRANTEE_NAMES"
        grantees = field.value
      when "GRANTOR_NAMES"
        grantors = field.value
      when "FULL_PROPERTY_ADDRESS"
        property = field.value
      end
    end

    return grantees, grantors, property
  end

  def get_balance_hash()
    hash = Hash.new
    hash["earnest_money"] = 0
    hash["loan_amount"] = 0
    hash["buyer"] = 0
    hash["seller"] = 0
    hash["loan_fees"] = []
    fees = 0

    @file.settlement_statements.each do |ss|
      case ss.ss_type
      when "default"
        # TODO: Need to figure out where to pull these amounts from
        # hash["buyer"] += ss.ss_lines.where("function = 'buyer_charges_balance_due'").first.cell_value.to_f
        # hash["seller"] += ss.ss_lines.where("function = 'seller_charges_balance_due'").first.cell_value.to_f
        # hash["earnest_money"] += hud.hud_lines.where("payee_id = #{@file.Company} AND number = 3001").sum("credits")
      when "hud"
        # TODO: This needs to be converted when we've finalized the HUD
        hash["buyer"] += hud.hud_lines.where("number = 303").first.borrower_amount.to_f
        hash["seller"] += -1 * hud.hud_lines.where("number = 603").first.seller_amount.to_f
        hash["earnest_money"] += hud.hud_lines.where("payee_id = #{@file.Company} AND name = 'Earnest Money' AND number > 700").sum("amount")
        hash["loan_amount"] += hud.initial_loan_amount.to_f + hud.hud_lines.where("number < 400 AND name = 'Lender Credit'").sum("borrower_amount")

        hud.hud_lines.where("number IN (803, 901, 902, 903, 1001, 1301) OR (number >= 805 AND number <= 820) AND description != '(from GFE #1)' ").each do |line|
          amount = line.borrower_amount.to_f
          unless line.has_disbursement?
            hash["loan_fees"] << line unless amount <= 0
            fees += amount
          end
        end
      end
    end

    hash["buyer"] = 0 if hash["buyer"] < 0
    hash["seller"] = 0 if hash["seller"] < 0
    hash["anticipated"] = hash["earnest_money"] + hash["loan_amount"] - fees + hash["buyer"] + hash["seller"]
    return hash
  end

  def payment_class(line)
    return "" if line.payment_amount == 0
    return line.payment_amount - line.payment_disbursements.sum("amount") == 0 ?  "green" : "red"
  end
end
