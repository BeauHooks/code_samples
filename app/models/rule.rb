class Rule < ActiveRecord::Base

  default_scope where("rules.removed_at IS NULL")
  default_scope order("rules.rule_text ASC")

  attr_accessible :created_by

  has_many :rule_names, conditions: "rule_names.removed_at IS NULL", order: "first_name ASC"
  has_many :rule_exceptions, conditions: "rule_exceptions.removed_at IS NULL"
  has_many :rule_triggers
  has_one :employee, class_name: "Employee", primary_key: "updated_by", foreign_key: "ID"
  has_one :reviewer, class_name: "Employee", primary_key: "reviewed_by", foreign_key: "ID"

  def has_trigger?(trigger)
    self.rule_triggers.where("rule_triggers.trigger_text = '#{trigger}'").first != nil
  end

  def modified_by
  	return employee != nil ? employee.FullName : ""
  end

  def reviewed_by
    return reviewer != nil ? reviewer.FullName : ""
  end

  def get_names
  	names = []
  	self.rule_names.each do |rule_name|
  		name = rule_name.full_name.to_s
  		names << name if name != ""
  	end
  	return names.join(" / ") || ""
  end

  def self.search(field, value = nil, from = nil, to = nil)
  	return [] if (value.to_s == "" && ["created_by", "full_name"].include?(field)) || (value.to_s == "" && from.to_s == "" && to.to_s == "" && field != "reviewed_at")

  	case field
  	when "created_by"
  		rules = Rule.find(:all, group: "rules.id", joins: [:employee], conditions: ["(tblEmployees.FullName LIKE '#{value}%%' OR tblEmployees.FullName LIKE '#{value.gsub(',', '').split(' ').reverse.join(' ')}%%')"])
  	when "full_name"
      rules = Rule.find(:all, group: "rules.id", joins: [:rule_names], conditions: ["rule_names.full_name LIKE '#{value}%%'"])
  	when "reviewed_at"
      rules = Rule.where("reviewed_at IS NULL OR reviewed_at < CAST('#{Time.now - 1.years}' AS DATE)")
    else
  		query = ""

  		if value.to_s != ""
  			value = value.gsub("'", "\\\\'").split("*").join("%%")
  			query += "#{field} LIKE '#{value}%%'"
  		end

  		if from.to_s != ""
        query += "CAST(#{field} AS DATE) >= CAST('#{self.parse_datetime(from)}' AS DATE)"
      end

      if to.to_s != ""
        query += " AND " if from != ""
        query += "CAST(#{field} AS DATE) <= CAST('#{self.parse_datetime(to)}' AS DATE)"
      end

      query != "" ? rules = Rule.find(:all, conditions: ["#{query}"]) : rules = []
  	end

  	return rules
  end

  def self.parse_datetime(datetime)
  	split      = datetime.split(' ')
    split_date = split[0].split('/')
    month      = split_date[0]
    day        = split_date[1]
    year       = split_date[2]
    date = DateTime.parse("#{year}-#{month}-#{day} #{split[1]} #{split[2]}").strftime("%Y-%m-%d %H:%M:%S")
  end

  def self.check_entity(entity, trigger = nil)
    conditions = []
    fields = RuleException.get_field_array
    operators = RuleException.get_operator_array

    fields.each do |field|
      value = entity.send(field.to_sym)
      operator_conditions = []
      operators.each do |operator|
        condition = "match_operator = \"#{operator}\" AND "
        case operator
        when "Contains"
          condition += "\"#{value}\" LIKE CONCAT(\"%%\", match_value, \"%%\")"
        when "Equal To"
          condition += "match_value LIKE \"#{value}\""
        when "Like"
          condition += "\"#{value}\" LIKE CONCAT(match_value, \"%%\")"
        end
        condition = "(#{condition})"
        operator_conditions << condition
      end

      conditions << "(match_field = \"#{field}\" AND (#{operator_conditions.join(' OR ')}) )"
    end

    remove_exceptions = self.remove_exceptions(conditions)
    self.get_rules(entity.name, remove_exceptions, trigger, entity.IndCorp)
  end

  def self.remove_exceptions(conditions)
    remove_exceptions = Rule.find(:all, group: "rules.id", joins: [:rule_exceptions], conditions: [conditions.join(' OR ')])
  end

  def self.check_name(name, trigger = nil)
    return [] if name == ""

    conditions = []
    fields = RuleException.get_field_array
    operators = RuleException.get_operator_array

    name = name.split(" ")

    fields.each do |field|
      unless field == "EntityID"
        case field
        when "FirstName"
          value = name.size > 1 ? name[0] : ""
        when "MiddleInitial"
          value = name.size > 2 ? name[1] : ""
        when "LastName"
          value = name.size == 2 ? name[1] : name.size == 3 ? name[2] : ""
        when "FullName"
          value = name.join(" ")
        end

        if value == ""
          next
        end

        operator_conditions = []
        operators.each do |operator|
          condition = "match_operator = \"#{operator}\" AND "
          case operator
          when "Contains"
            condition += "\"#{value}\" LIKE CONCAT(\"%%\", match_value, \"%%\")"
          when "Equal To"
            condition += "match_value LIKE \"#{value}\""
          when "Like"
            condition += "\"#{value}\" LIKE CONCAT(match_value, \"%%\")"
          end
          condition = "(#{condition})"
          operator_conditions << condition
        end

        conditions << "(match_field = \"#{field}\" AND (#{operator_conditions.join(' OR ')}) )"
      end
    end

    remove_exceptions = self.remove_exceptions(conditions)
    self.get_rules(name.join(" "), remove_exceptions, trigger)
  end

  def self.get_rules(match_name, remove_exceptions = [], trigger = nil, type = nil)
    conditions = []
    match_name = match_name.gsub(" ", "%%")

    type_condition = type == nil ? "" : type.titleize == "Individual" ? " AND name_type = 'Individual'" : " AND name_type != 'Individual'"

    # TO-DO: This needs to be changed back once triggers are in place
    # trigger = nil
    # trigger_condition = trigger != nil ? " AND trigger_text = '#{trigger}'" : ""
    trigger_condition = ""

    matches = Rule.find(:all, group: ["rules.id"], joins: [:rule_names, :rule_triggers], conditions: ["match_name LIKE \"%%#{match_name}%%\" #{type_condition} #{trigger_condition}"])
    # logger.debug "Matches: #{matches}"
    # logger.debug "Exceptions: #{remove_exceptions}"
    return matches - remove_exceptions
  end
end
