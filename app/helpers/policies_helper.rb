module PoliciesHelper
  def policy_type_select_list(policy_number)
    options = ""
    @rate_calculation.policy_types(policy_number).map { |p| options += "<option value='#{p.ID}'>#{p.PolicyDescription}</option>" }
    options.html_safe
  rescue
    ""
  end
end