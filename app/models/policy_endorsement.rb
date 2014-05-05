class PolicyEndorsement < ActiveRecord::Base

  after_save :save_history

  belongs_to :policy
  belongs_to :endorsement
  has_many :file_product_histories, primary_key: :id, foreign_key: :record_id

  delegate :schedule_a,   to: :policy,      prefix: false, allow_nil: true
  delegate :underwriter,  to: :schedule_a,  prefix: false, allow_nil: true
  delegate :file_product, to: :schedule_a,  prefix: false, allow_nil: true

  def save_history
    history_fields = ["endorsement_id", "amount"]
    self.changed.each do |key|
      if history_fields.include?(key) && !self.send(key + "_was").blank?
        FileProductHistory.create_history(self, key)
      end
    end
  end
end
