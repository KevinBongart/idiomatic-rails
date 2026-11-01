ActiveRecord::Schema[8.0].define(version: 1) do
  create_table "accounts", force: :cascade do |t|
    t.string "email", null: false
    t.string "nickname"
    t.string "handle"
    t.string "note"
    t.date "slot"
    t.bigint "account_id"
    t.string "kind"
    t.index ["email"], name: "index_accounts_on_email", unique: true
    t.unique_constraint ["account_id", "kind", "slot"], name: "index_accounts_on_slot"
  end
end
