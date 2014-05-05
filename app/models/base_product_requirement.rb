class BaseProductRequirement < ActiveRecord::Base

	default_scope { where("removed_at IS NULL").order("sort_order ASC") }

  belongs_to :base_product
	belongs_to :base_product_exception

end
