class SsGroup < ActiveRecord::Base
  has_many :ss_line_cells
  belongs_to :settlement_statement
end