class RuleException < ActiveRecord::Base

  attr_accessible :rule_id

  EXCEPTIONS = [["EntityID", "EntityID"],["First Name", "FirstName"], ["Full Name", "FullName"],["Middle Name", "MiddleInitial"],["Last Name", "LastName"]]
  FIELDS = ["EntityID", "FirstName", "FullName", "MiddleInitial", "LastName"]
  OPERATORS = ["Contains", "Equal To","Like"]

  def self.get_exceptions
  	EXCEPTIONS
  end

  def self.get_field_array
  	FIELDS
  end

  def self.get_operators
  	options = []
  	OPERATORS.each do |operator|
  		options << [operator, operator]
  	end
  end

  def self.get_operator_array
  	OPERATORS
  end
end
