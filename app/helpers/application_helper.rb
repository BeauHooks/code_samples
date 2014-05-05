require 'active_support/inflector'

module ApplicationHelper
  def page_name
    page = controller_name

    case page
    when "index"
      page = "File Index"
    when "admin"
      page = "Administration"
    else
      page = controller.controller_name.titleize
    end
  end

  def active(button)
    page = controller.controller_name
    active_class = ""

    if page.include?(button)
      active_class = " active"
    end
  end

  def company_name(company_id)
    Company.find(company_id).CompanyName
  end

  def random_string(length=10)
    string   = ''
    chars    = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ123456789'
    length.times { |i| string << chars[rand(chars.length)] }
    string
  end

  def doc_tags()
    tags = "'--Current Date Fields--': '', 'Current Date': '{{CURRENT_DATE}}', 'Current Day': '{{CURRENT_DAY}}', 'Current Month': '{{CURRENT_MONTH}}', 'Current Year': '{{CURRENT_YEAR}}', 'Current Date Written': '{{CURRENT_DATE_WRITTEN}}'"

    if DocStandardField.find(:all).count > 0
      tags += ", '--Standard Fields--': ''"
      DocStandardField.find(:all, order: "tag ASC").each do |field|
        tags += ", '#{field.tag.titleize}': '{{#{field.tag}}}'"
      end
    end

    tags += ", '--Functions--': '', 'Signatures': '{{SIGNATURES}}', 'Buyer Signatures': '{{BUYER_SIGNATURES}}', 'Seller Signatures': '{{SELLER_SIGNATURES}}',
      'Notary Function': '{{NOTARY_FUNCTION}}', 'Exhibit A Function': '{{EXHIBIT_A_FUNCTION}}', 'Attachment Function': '{{ATTACHMENT_FUNCTION}}', 'Page Break': '{{PAGE_BREAK}}', 'Company Logo': '{{COMPANY_LOGO}}'"
    return tags.html_safe
  end

  #TODO Create a helper method for show an employee select

  #TODO Error Handling for the views

  def flash_message
    html = flash.map do |key, msg|
      if key.to_s != "timedout"
        content_tag :div, msg, id: key, class: 'flash'
      end
    end.join
    html.html_safe
  end

  def sanitize_phone(number)
    number.to_s.gsub(/\D/, '')
  end

  def abbreviate_state(state)
    state.nil? ? return : nil
    states = {
      "Alabama"        => "AL",
      "Alaska"         => "AK",
      "Arizona"        => "AZ",
      "Arkansas"       => "AR",
      "California"     => "CA",
      "Colorado"       => "CO",
      "Connecticut"    => "CT",
      "Delaware"       => "DE",
      "Florida"        => "FL",
      "Georgia"        => "GA",
      "Hawaii"         => "HI",
      "Idaho"          => "ID",
      "Illinois"       => "IL",
      "Indiana"        => "IN",
      "Iowa"           => "IA",
      "Kansas"         => "KS",
      "Kentucky"       => "KY",
      "Louisiana"      => "LA",
      "Maine"          => "ME",
      "Maryland"       => "MD",
      "Massachusetts"  => "MA",
      "Michigan"       => "MI",
      "Minnesota"      => "MN",
      "Mississippi"    => "MS",
      "Missouri"       => "MO",
      "Montana"        => "MT",
      "Nebraska"       => "NE",
      "Nevada"         => "NV",
      "New Hampshire"  => "NH",
      "New Jersey"     => "NJ",
      "New Mexico"     => "NM",
      "New York"       => "NY",
      "North Carolina" => "NC",
      "North Dakota"   => "ND",
      "Ohio"           => "OH",
      "Oklahoma"       => "OK",
      "Oregon"         => "OR",
      "Pennsylvania"   => "PA",
      "Rhode Island"   => "RI",
      "South Carolina" => "SC",
      "South Dakota"   => "SD",
      "Tennessee"      => "TN",
      "Texas"          => "TX",
      "Utah"           => "UT",
      "Vermont"        => "VT",
      "Virginia"       => "VA",
      "Washington"     => "WA",
      "West Virginia"  => "WV",
      "Wisconsin"      => "WI",
      "Wyoming"        => "WY"
    }

    states[state.downcase.titlecase]
  end

  def state_collection
    states = [
      "Alabama"        ,
      "Alaska"         ,
      "Arizona"        ,
      "Arkansas"       ,
      "California"     ,
      "Colorado"       ,
      "Connecticut"    ,
      "Delaware"       ,
      "Florida"        ,
      "Georgia"        ,
      "Hawaii"         ,
      "Idaho"          ,
      "Illinois"       ,
      "Indiana"        ,
      "Iowa"           ,
      "Kansas"         ,
      "Kentucky"       ,
      "Louisiana"      ,
      "Maine"          ,
      "Maryland"       ,
      "Massachusetts"  ,
      "Michigan"       ,
      "Minnesota"      ,
      "Mississippi"    ,
      "Missouri"       ,
      "Montana"        ,
      "Nebraska"       ,
      "Nevada"         ,
      "New Hampshire"  ,
      "New Jersey"     ,
      "New Mexico"     ,
      "New York"       ,
      "North Carolina" ,
      "North Dakota"   ,
      "Ohio"           ,
      "Oklahoma"       ,
      "Oregon"         ,
      "Pennsylvania"   ,
      "Rhode Island"   ,
      "South Carolina" ,
      "South Dakota"   ,
      "Tennessee"      ,
      "Texas"          ,
      "Utah"           ,
      "Vermont"        ,
      "Virginia"       ,
      "Washington"     ,
      "West Virginia"  ,
      "Wisconsin"      ,
      "Wyoming"
    ]

    states.collect{|state| [state, state.upcase]}
  end

  def state_abbr_collection
    states = [
      ['AK', 'AK'],
      ['AL', 'AL'],
      ['AR', 'AR'],
      ['AZ', 'AZ'],
      ['CA', 'CA'],
      ['CO', 'CO'],
      ['CT', 'CT'],
      ['DC', 'DC'],
      ['DE', 'DE'],
      ['FL', 'FL'],
      ['GA', 'GA'],
      ['HI', 'HI'],
      ['IA', 'IA'],
      ['ID', 'ID'],
      ['IL', 'IL'],
      ['IN', 'IN'],
      ['KS', 'KS'],
      ['KY', 'KY'],
      ['LA', 'LA'],
      ['MA', 'MA'],
      ['MD', 'MD'],
      ['ME', 'ME'],
      ['MI', 'MI'],
      ['MN', 'MN'],
      ['MO', 'MO'],
      ['MS', 'MS'],
      ['MT', 'MT'],
      ['NC', 'NC'],
      ['ND', 'ND'],
      ['NE', 'NE'],
      ['NH', 'NH'],
      ['NJ', 'NJ'],
      ['NM', 'NM'],
      ['NV', 'NV'],
      ['NY', 'NY'],
      ['OH', 'OH'],
      ['OK', 'OK'],
      ['OR', 'OR'],
      ['PA', 'PA'],
      ['RI', 'RI'],
      ['SC', 'SC'],
      ['SD', 'SD'],
      ['TN', 'TN'],
      ['TX', 'TX'],
      ['UT', 'UT'],
      ['VA', 'VA'],
      ['VT', 'VT'],
      ['WA', 'WA'],
      ['WI', 'WI'],
      ['WV', 'WV'],
      ['WY', 'WY']
    ]

    states.collect{|state| [state, state.upcase]}
  end

  def format_value_for_display(format, value, unit = "")
    return if value.blank?
    case format
    when 'currency', 'decimal'
      number_to_currency(value, unit: unit)
    when 'date'
      value.to_date
    when 'round', 'integer'
      value.to_i
    else
      value
    end
  end

  def user_styles
    "<style type=\"text/css\">
      body, select, textarea, button, input{
        font-size: #{current_user.users_preferences["font-size"]};
        font-weight: #{current_user.users_preferences["font-weight"]};
      }
    </style>"
  end

  def link_to_add_fields(name, f, association)
    new_object = f.object.send(association).klass.new
    id = new_object.object_id
    fields = f.fields_for(association, new_object, child_index: id) do |builder|
      render(association.to_s.singularize + "_fields", f: builder)
    end
    link_to(name, '#', class: "add_fields", data: {id: id, fields: fields.gsub("\n", "")})
  end

  def build_usps_url(tax_id = nil, address1 = nil, address2 = nil, city = nil, state = nil, zip = nil)
    if city.blank? && !tax_id.blank?
      case tax_id.split("-")[0]
      when "SG"
        city = "St. George"
      when "SC"
        city = "Santa Clara"
      when "LV"
        city = "La Verkin"
      when "H"
        city = "Hurricane"
      when "R"
        city = "Rockville"
      when "I"
        city = "Ivins"
      when "L"
        city = "Leeds"
      when "W"
        city = "Washington"
      when "S"
        city = "Springdate"
      when "T"
        city = "Toquerville"
      when "V"
        city = "Veyo"
      when "E"
        city = "Enterprise"
      when "NH"
        city = "New Harmony"
      when "C"
        city = "Central"
      end
    end

    state = "Utah" if state.blank?

    url = "https://tools.usps.com/go/ZipLookupResultsAction!input.action?resultMode=0"
    url += "&address1=#{CGI.escape address1}" unless address1.blank?
    url += "&address2=#{CGI.escape address2}" unless address2.blank?
    url += "&city=#{CGI.escape city}" unless city.blank?
    url += "&state=#{CGI.escape state}" unless state.blank?
    url += "&zip=#{CGI.escape zip}" unless zip.blank?
    url
  end

  def hint_truncate(value, length, link=false)
    return if value.blank?
    if link
      link_value = />(.*?)<\/a>/.match(value)[1].to_s || ""

      if link_value.size > length
        %Q(
          <span class="hint_2">
            <span>
              <div>
                #{value}
              </div>
            </span>
            #{value.gsub(link_value, ActionView::Base.new.truncate(link_value, length: length))}
          </span>
        ).html_safe
      else
        value.html_safe
      end
    else
      if value.size > length
        %Q(
          <span class="hint_2">
            <span>
              <div>
                #{value}
              </div>
            </span>
            #{ActionView::Base.new.truncate(value, length: length)}
          </span>
        ).html_safe
      else
        value.html_safe
      end
    end
  rescue
    return
  end
end