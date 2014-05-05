module RolodexHelper
	def county_choices
		choices = ""
		County.find(:all, :order => "CountyName ASC").each do |county|
		  if choices == ""
		    choices += "'#{county.CountyName}'"
		  else
		    choices += ", '#{county.CountyName}'"
		  end
		end
		return choices.html_safe
	end

	def edit_rolodex_info_field(field, options={})
		case field
		when "Name"
		  "$('#rolodex_name').html('#{j(render 'rolodex/partials/info_field', type: 'Name').html_safe}');".html_safe
		when "Description"
		  "$('#rolodex_description').html('#{j(render 'rolodex/partials/info_field').html_safe}');".html_safe
		when "IndCorp"
		  "$('#rolodex_indcorp').html('#{j(render 'rolodex/partials/info_field').html_safe}');".html_safe
		when "CustomerType"
		  "$('#rolodex_customer_type').html('#{j(render 'rolodex/partials/info_field').html_safe}');".html_safe
		when "SendDocsVia"
		  "$('#rolodex_send').html('#{j(render 'rolodex/partials/info_field').html_safe}');".html_safe
		when "Employee"
		  "$('#rolodex_employee').html('#{j(render 'rolodex/partials/info_field').html_safe}');".html_safe
		when "IsActive"
		  "$('#rolodex_active').html('#{j(render 'rolodex/partials/info_field').html_safe}');".html_safe
		when "EffectiveDate"
		  "$('#rolodex_effective_date').html('#{j(render 'rolodex/partials/info_field').html_safe}');".html_safe
		when "TaxID"
		  "$('#rolodex_tax_id').html('#{j(render 'rolodex/partials/info_field').html_safe}');".html_safe
		when "Rule"
		  "$('#rolodex_rule_#{options[:rule].ID}').html('#{j(render 'rolodex/partials/info_field').html_safe}');".html_safe
		end
	end
end