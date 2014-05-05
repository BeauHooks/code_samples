class Policy < ActiveRecord::Base

  before_destroy :update_sort_order
  after_save     :save_history

  default_scope {order("sort_order ASC")}

  belongs_to :schedule_a
  belongs_to :policy_type
  has_many   :policy_endorsements, dependent: :destroy, conditions: "policy_endorsements.removed_at IS NULL"
  has_many   :file_product_histories, primary_key: :id, foreign_key: :record_id

  delegate   :file_product, to: :schedule_a, prefix: false, allow_nil: true
  delegate   :underwriter,  to: :schedule_a, prefix: false, allow_nil: true

  def self.checkboxes
    ["is_refinance", "use_developer_rate"]
  end

  def update_sort_order
    policies = self.schedule_a.policies.where("id != #{self.id}")
    current = 0

    policies.each do |p|
      p.sort_order = current += 1
      p.save
    end
  end

  def save_history
    exclude_fields = ["updated_by", "updated_at", "removed_by", "removed_at", "created_by", "created_at"]
    self.changed.each do |key|
      unless exclude_fields.include?(key) || self.send(key + "_was").blank?
        FileProductHistory.create_history(self, key)
      end
    end
  end

  def type
    self.policy_type.nil? ? "" : self.policy_type.PolicyDescription
  end
end