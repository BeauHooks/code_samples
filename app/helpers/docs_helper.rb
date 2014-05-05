module DocsHelper
  def placeholder(cell)
    return "" if cell.cell_name.include?("charges") || cell.cell_name.include?("credits") || @print != nil
    return cell.cell_name.to_s.titleize.sub("Proration ", "") if cell.cell_name.include?("proration_")

    case cell.cell_name
    when "name"
      if cell.ss_line.line_type == "header"
        return "Header"
      else
        return "Description"
      end
    when "poc"
      return "POC"
    else
      return cell.cell_name.to_s.titleize
    end
  end

  def get_address_group_options
    grouped_options = [
      ["Options",
        [["Current", "current"], ["Property", "property"], ["New", "new"]]
      ]
    ]

    if @entity != nil
      collection = @entity.entity_contacts.where("ContactType = 'ADDRESS' AND IsActive = -1").collect{|c| [c.description, c.ContactID]}
      grouped_options << ["Addresses", collection] if collection.count > 0
    end
    return grouped_options
  end

  #
  # Document Print helpers
  #
  def print_doc
    files    = []
    batch_id = random_string
    list     = ""
    doc_style    = open(Rails.root.join("app/assets/stylesheets/print/doc_print.css"), "rb").read
    ss_style    = doc_style + open(Rails.root.join("app/assets/stylesheets/tru_15.css"), "rb").read + open(Rails.root.join("app/assets/stylesheets/base/ss.css"), "rb").read + open(Rails.root.join("app/assets/stylesheets/print/ss_print.css"), "rb").read
    @docs.each do |d|
      @n                         += 1
      @doc                       = Doc.find d
      @html                      = get_doc(@doc, :pdf => true)
      # print                      = DocPrint.new
      # print.batch_id             = @n.to_s + "_" + batch_id
      # print.doc_id               = @doc.id
      # print.doc_template_id      = @doc.doc_template_id
      # print.doc_template_version = @doc.doc_template_version
      # print.compiled_text        = @html
      # print.printed_by           = current_user.employee_id
      # print.printed_at           = Time.now
      # print.save

      if @doc.doc_template.short_name == "SS"
        style = ss_style
      else
        style = doc_style
      end

      if @docs.count == 1
        @content = @html
        file  = save_html("<style>#{@side}#{style}</style>#{@content}")
        return file
      else
        @content = "<style>#{@side}#{style}</style>" + @html
        files << save_html("#{@content}")
      end
    end
    if files.count > 0
      files.each do |f|
        list = list + "content[]=#{f}&"
      end
      return list
    end
  end

  def save_html(html)
    footer = ""
    header = ""
    cookies = ""
    header_spacing = ""

    # if @doc.doc_template.sub_category == "Recording"
    #   margin_top    = '.85in'
    #   margin_right  = '.85in'
    #   margin_bottom = '.85in'
    #   margin_left   = '.85in'
    # else
    #   margin_top    = '0.5in'
    #   margin_right  = '0.5in'
    #   margin_bottom = '0.5in'
    #   margin_left   = '0.5in'
    # end

    form_docs = ["HUD", "W9", "ACK", "CEA", "SA", "SS", "LSS", "AFFPV", "RIC", "WRA", "RF"]
    short_name = @doc.doc_template.short_name
    if form_docs.include?(short_name)
      margin_bottom = '0.5in'
      margin_top    = '0.5in'
      margin_right  = '0.5in'
      margin_left   = '0.5in'

      case short_name
      when "HUD"
        footer = "#{Rails.root.join("app/views/docs/footers/hud_footer.html")}"
        margin_right  = '0.375in'
        margin_bottom = '0.7in'
        margin_left   = '0.375in'
      when "W9"
        footer = "#{Rails.root.join("app/views/docs/footers/w9_footer.html")}"
        margin_right  = '0.3in'
        margin_bottom = '0.6in'
        margin_left   = '0.3in'
      when "ACK"
        footer = "#{Rails.root.join("app/views/docs/footers/ack_footer.html")}"
        margin_bottom = '0.6in'
      when "CEA"
        footer = "#{Rails.root.join("app/views/docs/footers/cea_footer.html")}"
        header = "#{Rails.root.join("app/views/docs/headers/cea_header.html")}"
        margin_top = '0.6in'
        margin_bottom = '0.6in'
      when "SA"
        header = "#{Rails.root.join("app/views/docs/headers/sa_header.html")}"
        margin_top = '0.6in'
      when "SS"
        case @doc.settlement_statement.ss_type
        when "hud"
          footer = "#{Rails.root.join("app/views/docs/footers/ss_hud_footer.html")}"
          margin_bottom = '0.6in'

          field = @doc.file_doc_fields.where("tag = 'LOAN_ID' AND is_active != 0").first
          field = @file.file_doc_fields.where("tag = 'LOAN_ID'").first if field.nil?
          cookies += "**loan_id=#{field.nil? ? "NULL" : field.value}"
        else
          footer = "#{Rails.root.join("app/views/docs/footers/ss_default_footer.html")}"
          margin_bottom = '0.6in'
        end
      when "LSS"
        footer = "#{Rails.root.join("app/views/docs/footers/ss_footer.html")}"
        margin_bottom = '0.6in'
      end
    else
      margin_top    = '1in'
      margin_right  = '1in'
      margin_bottom = '1in'
      margin_left   = '1in'

      case short_name
      when "BLANK"
        footer = "#{Rails.root.join("app/views/docs/footers/blank_footer.html")}"
        margin_bottom = '1.15in'
      # when "WD", "CWD", "QCD"
      #   header = "#{Rails.root.join("app/views/docs/headers/deed_header.html")}"
      #   cookies = "doc_name=#{@doc.doc_template.description}"
      #   ["GRANTOR_VESTING", "GRANTEE_VESTING", "PROPERTY_TAX_ID", "FILE_ID_NUMBER"].each do |tag|
      #     field = @doc.file_doc_fields.where("tag = '#{tag}' AND is_active != 0").first
      #     field = @file.file_doc_fields.where("tag = '#{tag}'").first if field.nil?
      #     cookies += "**#{tag.downcase}=#{field.nil? ? "NULL" : field.value}"
      #   end
      when "BL", "SL"
        footer = "#{Rails.root.join("app/views/docs/footers/letter_footer.html")}"
        margin_bottom = '1.15in'
      when "HBA"
        header = "#{Rails.root.join("app/views/docs/headers/hba_header.html")}"
        footer = "#{Rails.root.join("app/views/docs/footers/hba_footer.html")}"
        margin_top = '1.15in'
        margin_bottom = '1.15in'
        field = @doc.file_doc_fields.where("is_active != 0 AND tag='COMPANY_NAME'").first
        field = @file.file_doc_fields.where("tag='COMPANY_NAME'").first if field.blank?
        cookies = "file_id_number=#{@file.DisplayFileID}**company_name=#{field.value unless field.blank?}"
      when "PSIFA"
        footer = "#{Rails.root.join("app/views/docs/footers/psifa_footer.html")}"
        margin_bottom = "1.15in"
      end
    end

    if ["TD", "TDS", "TDL"].include?(@doc.doc_template.short_name)
      footer = "#{Rails.root.join("app/views/docs/footers/td_footer.html")}"
      margin_bottom = '1.05in'
    end

    @pdf = PDFKit.new(html, {
      footer_html: ("#{footer}" if footer != ""),
      header_html: ("#{header}" if header != ""),
      title: "#{@file.DisplayFileID}",
      margin_top:"#{margin_top}",
      margin_right:"#{margin_right}",
      margin_bottom:"#{margin_bottom}",
      margin_left:"#{margin_left}",
      # header_spacing: "#{header_spacing != "" ? header_spacing : ""}",
      cookie: cookies
    }).to_pdf

    filename = random_string + ".pdf"
    path = File.expand_path(filename, Rails.root + "tmp/docs/")
    file = File.new(path, "w+b")
    file.puts @pdf.to_s
    file.close

    return filename
  end
  #
  # Rolodex Signature Tree helpers
  #
  def tree_list(signature)
    @signature = signature
    parent     = @signature.rolodex_signature_entities.where("parent_id = 0").first
    html       = ""
    partial    = "rolodex_signatures/add_to_show"

    if parent != nil
      html = get_children(parent, partial)
    end
    return html
  end

  def get_sig_children(parent, signature, partial)
    return if parent == nil
    @signature_entity = parent
    @signature = signature
    html = render partial: partial

    if @signature.rolodex_signature_entities.where("parent_id = #{parent.id}").first != nil
      @signature.rolodex_signature_entities.where("parent_id = #{parent.id}").each do |child|
        html += get_children(child, partial)
      end
    end

    return html
  end

  def generate_signature_tree(signature)
    @signature = signature
    parent = @signature.rolodex_signature_entities.where("parent_id = 0").first
    html = ""
    partial = "rolodex_signatures/block"

    if parent != nil
      html += get_children(parent, partial)
    end
    return html
  end
  ###

  def normalize_tag(tag)
    tag.downcase
  end

  def get_doc_entities(doc_id, file_id)
    file = Index.find file_id
    list = ""

    if doc_id == "" || doc_id == nil
      doc_id = 0
    end

    file.file_doc_entities.where("doc_id = #{doc_id} AND is_active = 1").each do |i|
      list += ", #{i.entity_id}"
    end
    return list
  end

  def get_doc_entity(doc_id)
    if doc_id != 0
      doc = Doc.find doc_id
      if doc.doc_entity_id != nil
        return doc.doc_entity
      end
    end
    return nil
  end

  def get_doc_signature_type(doc)
    if doc.doc_signature_type != nil
      name =  doc.doc_signature_type.name
      name = name.split("_")
      return name[0], name[1]
    else
      return "", ""
    end
  end

  def generate_blocks(doc)
    @w = {}
    @x = []
    @y = []
    @z = []

    @x << doc.template_text.to_s.scan(/\{{(.*?_BLOCK)\}}/)

    @x.each do |a|
      @y << a
    end

    @y.each do |a|
      @z << a
    end

    @z[0].each do |i|
      if DocBlock.all.count > 0
        DocBlock.all.each do |f|
          if normalize_tag(i[0]) == normalize_tag(f.tag)
            @w[i[0]] = f.value
          else
            if @w.has_key?(i[0]) == false
              @w[i[0]] = ""
            end
          end
        end
      else
        @w[i[0]] = ""
      end
    end

    blocks = Hash.new
    @w.each do |k,v|
      blocks[k] = v
    end

    blocks
  end

  def generate_options
    @w = {}
    scan = []
    fields = []

    scan << @template.scan(/({{OPTION_(.*?){{END_OPTION(.*?)}})/m)

    scan[0].each do |a|
      fields << a[0]
    end

    func = DocFunction.where("name = 'OPTION_FUNCTION' ").first.value rescue "Option Function Does Not Exist"
    options = Hash.new
    fields.each do |option|
      begin
        @option = option
        @key = @option.gsub(/((}}.*?)({{END_OPTION_.*?)}})/m, "")[2..-1]
        @option_text = @option.gsub(/({{OPTION_(.*?)}})/, "").gsub(/({{END_OPTION_(.*?)}})/, "")

        v = eval(func)
      rescue
        logger.info "******************Doc Option ERROR**************************"
        logger.info $!.inspect
        logger.info "**************************************************************"
        v = "<h4 style='color:red'>**ERROR: Syntax Error**</h4>"
      end
      # options[@key] = v.to_s.gsub(/\n/, "")
      @template = @template.sub(/\{\{#{@key}\}\}(.*?)\{\{END_#{@key}\}\}/m, v.html_safe)#.to_s.gsub(/\n/, ""))
    end

    return options
  end


  def generate_checkboxes
    @w = {}
    scan = []
    fields = []

    scan << @template.scan(/\{{(CB_.*?)\}}/)

    scan[0].each do |a|
      fields << a[0]
    end

    func = DocFunction.where("name = 'CHECKBOX_FUNCTION' ").first.value rescue "Checkbox Function Does Not Exist"

    boxes = Hash.new
    fields.each do |field|
      begin
        @key = field
        v = eval(func)
      rescue
        logger.info "******************Doc Checkbox ERROR**************************"
        logger.info $!.inspect
        logger.info "**************************************************************"
        v = "<h4 style='color:red'>**ERROR: Syntax Error**</h4>"
      end
      boxes[field] = v
    end

    return boxes
  end

  def generate_text_inputs
    @w = {}
    scan = []
    fields = []

    scan << @template.scan(/({{TXT_(.*?)}})/m)

    scan[0].each do |a|
      fields << a[0]
    end

    func = DocFunction.where("name = 'TEXT_FUNCTION' ").first.value rescue "Text Function Does Not Exist"
    fields.each do |field|
      begin
        @key = field.gsub(/\{\{/m, "").gsub(/\}\}/m, "")
        v = eval(func)
      rescue
        logger.info "******************Doc Text ERROR**************************"
        logger.info $!.inspect
        logger.info func
        logger.info field
        logger.info v
        logger.info "**************************************************************"
        v = "<h4 style='color:red'>**ERROR: Text Syntax Error**</h4>"
      end
      @template = @template.sub(/\{\{#{@key}\}\}/m, v.html_safe)
    end
  end

  def run_functions(template)
    @w = {}
    @x = []
    @y = []
    @z = []

    @x << @template.scan(/\{{(.*?_FUNCTION)\}}/)

    @x.each do |a|
      @y << a
    end

    @y.each do |a|
      @z << a
    end

    @z[0].each do |i|
      if DocFunction.all.count > 0
        DocFunction.all.each do |f|
          if normalize_tag(i[0]) == normalize_tag(f.name)
            @w[i[0]] = f.value
          else
            if @w.has_key?(i[0]) == false
              @w[i[0]] = ""
            end
          end
        end
      else
        @w[i[0]] = ""
      end
    end

    functions = Hash.new
    @w.each do |k,v|
      begin
        if v == ""
          v
        else
          v = eval(v)
        end
      rescue
        logger.info "******************Doc Function ERROR**************************"
        logger.info $!.inspect
        logger.info "**************************************************************"
        v = "<h4 style='color:red'>**ERROR: Syntax Error**</h4>"
      end
      functions[k] = v
    end

    return functions
  end

  def generate_signature_block(doc)
    @doc        = doc
    @sig_name   = @doc.doc_signature_type.name
    @entities   = @sig_name.split("_")[0]
    @position   = @sig_name.split("_")[1]
    @file = Index.where("FileID = #{@doc.file_id}").first

    if @doc.file_doc_entities.count > 0 || @file.file_doc_entities.count > 0
      @sig_block  = render("docs/doc_signature")
    else
      @sig_block = ""
    end
    return @sig_block
  end

  def random_string(length=10)
    string   = ''
    chars    = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ123456789'
    length.times { |i| string << chars[rand(chars.length)] }
    string
  end

  def get_company_logo
    if [101, 103, 106].include?(@file.Company)
      logo = "doc_logo_sutc.png"
    elsif @file.Company == 102
      logo = "doc_logo_terra.png"
    else
      return ""
    end

    if @print == nil
      return "<img src='assets/sm_#{logo}' />"
    else
      return "<img src='#{Rails.root}/public/images/#{logo}' style='height: 5em;' />"
    end
  end

  def get_company_insignia
    if [101, 103, 106].include?(@file.Company)
      insignia = "doc_insignia_sutc.png"
    elsif @file.Company == 102
      insignia = "doc_insignia_terra.png"
    else
      return ""
    end

    if @print == nil
      return "<img src='assets/sm_#{insignia}' />"
    else
      return "<img src='#{Rails.root}/public/images/#{insignia}' style='height: 5em;' />"
    end
  end

  def get_doc(doc,options={})
    @file     = Index.where("FileID = #{doc.file_id}").first
    @template = doc.template_text.to_s
    @scan = []
    @scan << @template.scan(/\{{(.*?)\}}/)
    @doc = doc

    @time_taken =  0
    if @doc.doc_template.short_name == "HUD" || @doc.doc_template.short_name == "LSS"
      @hud = @doc.hud
      @hud_type = @doc.doc_template.short_name
      @template = @template.gsub("{{HUD_CONTENT}}", render(partial: "/huds/hud_content"))
    elsif @doc.doc_template.short_name == "SS"
      @hud_type = @doc.doc_template.short_name
      @template = @template.gsub("{{HUD_CONTENT}}", render("/settlement_statements/show"))
    elsif @doc.doc_template.short_name == "INV"
      @invoice = @doc.invoice
      @template = @template.gsub("{{INVOICE_CONTENT}}", render(partial: "/invoice/content"))
    elsif @doc.doc_template.short_name == "1099"
      @template = @template.gsub("{{COMPANY_NAME}}", @file.company.CompanyName).gsub("{{FILE_ID_NUMBER}}", @file.DisplayFileID.to_s).gsub("{{COMPANY_TAX_ID}}", @file.company.TaxID)
    elsif @doc.doc_template.short_name == "BL"
      @template = @template.gsub("{{COMPANY_NAME}}", @file.company.CompanyName)
    end

    company = @file.company
    @template = @template.gsub("{{COMPANY_BANK_INFO}}", "#{company.BankName}<br />#{company.BankAddress}<br />#{company.BankCSZ}")
                .gsub("{{COMPANY_BANK_NAME}}", company.BankName)
                .gsub("{{COMPANY_ROUTING}}", company.BankWireRouting)
                .gsub("{{COMPANY_ACCOUNT_NUMBER}}", company.BankMicrAccountNum)
                .gsub("{{COMPANY_ACCOUNT_NAME}}", "#{company.CompanyName}<br />TRUST ACCOUNT")

    @fields = @file.file_doc_fields
    @pdf = options[:pdf]

    if doc.doc_signature_type != nil
      @signature_block = generate_signature_block(doc)

      if @signature_block != ""
        @template = @template.gsub("{{SIGNATURES}}", @signature_block)

        if @template.include?("{{BUYER_SIGNATURES}}")
          @force_hide = "Seller"
          @signature_block = generate_signature_block(doc)
          @template = @template.gsub("{{BUYER_SIGNATURES}}", @signature_block)
        end

        if @template.include?("{{SELLER_SIGNATURES}}")
          @force_hide = "Buyer"
          @signature_block = generate_signature_block(doc)
          @template = @template.gsub("{{SELLER_SIGNATURES}}", @signature_block)
        end

      end

      @force_hide = nil
      @signature_block = generate_signature_block(doc)
    end

    generate_options # The template updates as it goes
    generate_text_inputs # The template updates as it goes

    checkboxes = generate_checkboxes
    checkboxes.each do |k, v|
      if v != nil
        @template = @template.gsub("{{#{k}}}", v)
      end
    end

    @functions = run_functions(@template)
    @functions.each do |k,v|
      if v != nil
        @template = @template.gsub("{{#{k}}}", v)
      else
        @template = @template.gsub("{{#{k}}}", "<h4 style='color:red'>**ERROR: Can't Find Function**</h4>")
      end
    end

    @blocks   = generate_blocks(doc)
    @blocks.each do |k,v|
      if v != nil
        @template = @template.gsub("{{#{k}}}", v)
      else
        @template = @template.gsub("{{#{k}}}", "")
      end
    end

    if @pdf
      @template = @template.gsub("{{PAGE_BREAK}}", "<div style='page-break-before:always;'></div>")
    else
      @template = @template.gsub("{{PAGE_BREAK}}", "<center style='color:blue'>--------------------------PAGE BREAK--------------------------</center>")
    end

    @template = @template.gsub("{{CURRENT_DATE}}", "#{Time.now.to_date.strftime('%m/%d/%Y')}")
                .gsub("{{CURRENT_DAY}}", "#{Time.now.day}")
                .gsub("{{CURRENT_MONTH}}", "#{Time.now.month}")
                .gsub("{{CURRENT_YEAR}}", "#{Time.now.year}")
                .gsub("{{DATE}}", "#{Time.now.to_date.strftime('%m/%d/%Y')}")
                .gsub("{{CURRENT_DATE_WRITTEN}}", "#{Time.now.to_date.strftime("%B %e, %Y").gsub(/\s\s/, " ")}")
                .gsub("{{COMPANY_LOGO}}", get_company_logo() )
                .gsub("{{COMPANY_INSIGNIA}}", get_company_insignia() )
                .gsub("{{UNDERWRITER_NAME}}", @file.underwriter_name)
                .gsub("{{GRANTOR_CSZ}}", FileDocField.get_csz('GRANTOR_CSZ', doc))
                .gsub("{{GRANTEE_CSZ}}", FileDocField.get_csz('GRANTEE_CSZ', doc))
                .gsub("{{PROPERTY_CSZ}}", FileDocField.get_csz('PROPERTY_CSZ', doc))

    @fields, @template   = generate_fields(@file, @fields, doc, @template, @pdf)
    @fields.each do |k,v|
      if v != nil
        if @pdf == true
          #
          # On printing the PDF, check to see if any of these function exist and if so, replace them with the proper value
          #
          value = v.to_f
          @template = @template.gsub("{{#{k}}}.currency_to_words", v != "0" && value == 0 ? "INVALID NUMBER" : number_to_currency_in_words(v.to_f).upcase)
          @template = @template.gsub("{{#{k}}}.number_to_currency", v != "0" && value == 0 ? "INVALID NUMBER" : number_to_currency(v.to_f))
          @template = @template.gsub("{{#{k}}}.percent_to_words", v != "0" && value == 0 ? "INVALID NUMBER" : (v.to_f.to_words + " PERCENT").upcase)
          @template = @template.gsub("{{#{k}}}.number_to_words", v != "0" && value == 0 ? "INVALID NUMBER" : v.to_f.to_words.upcase)
          @template = @template.gsub("{{#{k}}}.date_long", date_long(v))
        end
        @template = @template.gsub("{{#{k}}}", v)
        #@template = @template.gsub("#{v}.percent_to_currency2", number_to_currency_in_words(v.match(/">(.*?)<\/a><\/span>/).captures.first.to_f, connector: ' and ').upcase) if @pdf == true
        #@template = @template.gsub("{{#{k}}}.percent_to_words2", (v.match(/">(.*?)<\/a><\/span>/).captures.first.to_f.to_words + " percent").upcase) if @pdf == false
      else
        if @pdf == true
          @template = @template.gsub("{{#{k}}}", "")
        else
          @template = @template.gsub("{{#{k}}}", "{{#{k}}}")
        end
      end
    end



    #@template = ERB.new(@template.gsub("&lt;", "<").gsub("&gt;", ">").html_safe).result.html_safe

    #@template = @template.gsub(/\r?\n/, "<br />").html_safe
    @template = @template.html_safe
  end

  def date_long(value)
    if value.include?("/")
      date_object = Date.strptime(value, "%m/%d/%Y")
    else
      date_object = Date.strptime(value, "%m-%d-%Y")
    end
    return "#{date_object.day.ordinalize} day of #{date_object.strftime('%B')}, the year #{date_object.year}"
    rescue
      return "INVALID DATE"
  end

  def generate_fields(file, fields, doc, template, pdf)
    @w = {}
    @x = []
    @y = []
    @z = []

    if doc.doc_entity_id != nil
      doc_name = doc.doc_template.short_name
      doc_entity_id = doc.doc_entity_id
      scan = []

      scan << template.scan(/\{{(.*?)\}}/)

      scan[0].each do |a|
        if a[0].split("_")[0] == doc_name && doc_entity_id != nil
          template = template.gsub("{{#{a[0]}}}", "{{#{a[0]}_#{doc_entity_id}}}")
          a[0] = "#{a[0]}_#{doc_entity_id}"
        end
      end
    end

    @x << template.scan(/\{{(.*?)\}}/)

    @x.each do |a|
      @y << a
    end

    @y.each do |a|
      @z << a
    end

    if fields == nil || fields == ""
      fields = []
    end

    @z[0].each do |i|
      if fields.count > 0
        fields.where("is_active = 1").order("doc_id ASC").each do |f|
          if normalize_tag(i[0].gsub("_TEXT","")) == normalize_tag(f.tag)
            if f.doc_id == doc.id
              if f.value != ""
                @w[i[0]] = "#{f.value}_custom"
              else
                @w[i[0]] = "_custom"
              end
            elsif f.doc_id == 0
              if @w[i[0]].to_s.end_with?("_custom") == false
                if f.value != ""
                  @w[i[0]] = "#{f.value}_global"
                else
                  @w[i[0]] = "_global"
                end
              end
            end
          else
            if @w.has_key?(i[0]) == false
              @w[i[0]] = ""
            end
          end
        end
      else
        @w[i[0]] = ""
      end
    end

    spans = Hash.new
    if fields != nil
      if pdf != true
        @w.each do |k,v|
          if k.end_with?("_TEXT")
            v = v.gsub("_global", "")
            spans[k] = "#{v}"
          elsif v == "_global" || v == ""
            spans[k] = "<span id='global_#{normalize_tag(k)}' name='global_#{normalize_tag(k)}' class='trigger'><a href='docs/edit_custom_field?file_id=#{file.ID}&doc_id=#{doc.id}&field=global_#{normalize_tag(k)}' data-remote='true' class='#{normalize_tag(k) != '' ? 'complete' : 'error'}'>{{#{k}}}</a></span>"
          elsif v == "_custom"
            spans[k] = "<span id='global_#{normalize_tag(k)}' name='global_#{normalize_tag(k)}' class='trigger'><a href='docs/edit_custom_field?file_id=#{file.ID}&doc_id=#{doc.id}&field=global_#{normalize_tag(k)}' data-remote='true' class='#{normalize_tag(k) != '' ? 'custom' : 'error'}'>{{#{k}}}</a></span>"
          else
            if k.end_with?("_TEXT")
              spans[k] = "#{v}"
            elsif v.end_with?("_custom")
              v = v.gsub("_custom", "").gsub(/\n/, "<br />")
              spans[k] = "<span id='custom_#{normalize_tag(k)}' name='custom_#{normalize_tag(k)}' class='trigger'><a href=\"docs/edit_custom_field?file_id=#{file.ID}&doc_id=#{doc.id}&field=custom_#{normalize_tag(k)}\" data-remote='true' class='#{normalize_tag(k) != '' ? 'custom' : 'error'}'>#{k.include?('FULL_PROPERTY_ADDRESS') ? v[0...39] : v}</a></span>"
            elsif v.end_with?("_global")
              v = v.gsub("_global", "").gsub(/\n/, "<br />")
              spans[k] = "<span id='global_#{normalize_tag(k)}' name='global_#{normalize_tag(k)}' class='trigger'><a href=\"docs/edit_custom_field?file_id=#{file.ID}&doc_id=#{doc.id}&field=global_#{normalize_tag(k)}\" data-remote='true' class='#{normalize_tag(k) != '' ? 'global' : 'error'}'>#{k.include?('FULL_PROPERTY_ADDRESS') ? v[0...39] : v}</a></span>"
            end
          end
        end
      else
        @w.each do |k,v|
          if v == "_global" || v == ""
            spans[k] = ""
          elsif v == "_custom"
            spans[k] = ""
          else
            if v.end_with?("_custom")
              v = v.gsub("_custom", "")
              spans[k] = "#{k.include?('FULL_PROPERTY_ADDRESS') ? v[0...39] : v}"
            elsif v.end_with?("_global")
              v = v.gsub("_global", "")
              spans[k] = "#{k.include?('FULL_PROPERTY_ADDRESS') ? v[0...39] : v}"
            end
          end
        end
      end
    end
    return spans, template
  end
end
