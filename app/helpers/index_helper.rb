module IndexHelper
  def print_confirmation
    footer = ""
    header = ""
    margin_top    = '0.5in'
    margin_right  = '0.5in'
    margin_bottom = '0.5in'
    margin_left   = '0.5in'

    begin
      html = render template: "feedback_mailer/file_confirmation_email"
      html = ("<html>" + html.split("</html>")[0].split("<html>")[1] + "</html>").html_safe

      @pdf = PDFKit.new(html, {footer_html: ("#{footer}" if footer != ""), header_html: ("#{header}" if header != ""), title: "#{@file.DisplayFileID}", margin_top:"#{margin_top}", margin_right:"#{margin_right}", margin_bottom:"#{margin_bottom}", margin_left:"#{margin_left}"  }).to_pdf
      filename = random_string + ".pdf"
      path = File.expand_path(filename, Rails.root + "tmp/confirmation_images/")
      file = File.new(path, "w+b")
      file.puts @pdf.to_s
      file.close
    rescue => ex
      @error = ex.message
      return "error"
    end

    return filename
  end

  def get_settlement_statement(type)
    case type
    when "default"
      return render partial: "/settlement_statements/default"
    when "hud"
      return render partial: "/settlement_statements/hud"
    when "standard"
      return render partial: "/huds/normal"
    else
      return "<p class='error'>*************Settlement Statement Not Found*************</p>"
    end
  end
end