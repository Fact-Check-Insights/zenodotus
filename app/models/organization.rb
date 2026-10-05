# A group of users, e.g. a newsroom or fact-checking team, used to report usage across its members.
# Not to be confused with `FactCheckOrganization`, which is the publisher of scraped fact-checks.
class Organization < ApplicationRecord
  has_many :users, dependent: :nullify

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  normalizes :name, with: ->(name) { name.strip }
end
