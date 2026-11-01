class Account < ApplicationRecord
  validates :email, presence: true, uniqueness: true
  validates :nickname, presence: true
  validates :handle, uniqueness: true
  validates :note, presence: true, if: :fussy?
  validates :slot, uniqueness: { scope: [ :account_id, :kind ] }
end
