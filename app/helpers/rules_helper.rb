module RulesHelper
	def get_trigger_options
		options = []
		RuleTrigger.get_trigger_list.each do |trigger|
			options << [trigger, trigger]
		end
		return options
	end
end
