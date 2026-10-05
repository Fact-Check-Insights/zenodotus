# Usage statistics for the members of an `Organization` over a date range, broken down by month and by user.
#
# Usage is attributed to the organization a user belongs to *now*: moving a user to another organization
# moves their whole history with them.
class OrganizationUsageReport
  # Each metric is a relation of records with `user_id` and `created_at` columns, plus a label for display.
  METRICS = {
    archived_items: "Archived items",
    scrape_requests: "Scrape requests",
    failed_scrapes: "Failed scrapes",
    text_searches: "Text searches",
    image_searches: "Image searches",
    corpus_downloads: "Corpus downloads",
  }.freeze

  attr_reader :organization, :from, :to

  def initialize(organization, from:, to:)
    @organization = organization
    @from, @to = [from, to].minmax
  end

  # The first day of every month in the range, oldest first
  def months
    first = from.beginning_of_month
    last = to.beginning_of_month
    months = []
    while first <= last
      months << first
      first = first.next_month
    end
    months
  end

  def users
    @users ||= organization.users.order(:name).to_a
  end

  # { metric => count } for the whole organization over the range
  def totals
    sum_counts { |_user_id, _month| true }
  end

  # { month => { metric => count } } for the whole organization
  def by_month
    months.index_with { |month| sum_counts { |_user_id, m| m == month } }
  end

  # { user => { metric => count } } over the range, including users with no usage
  def by_user
    users.index_with { |user| sum_counts { |user_id, _month| user_id == user.id } }
  end

  # { user => { month => { metric => count } } }
  def by_user_and_month
    users.index_with do |user|
      months.index_with { |month| sum_counts { |user_id, m| user_id == user.id && m == month } }
    end
  end

private

  def sum_counts
    METRICS.keys.index_with do |metric|
      counts[metric].sum { |(user_id, month), count| yield(user_id, month) ? count : 0 }
    end
  end

  # { metric => { [user_id, month] => count } }, one grouped query per metric
  def counts
    @counts ||= METRICS.keys.index_with do |metric|
      relation = relation_for(metric)
      table = relation.klass.quoted_table_name

      relation
        .where(user_id: users.map(&:id), created_at: from.beginning_of_day..to.end_of_day)
        .group(:user_id, Arel.sql("date_trunc('month', #{table}.created_at)"))
        .count
        .transform_keys { |(user_id, month)| [user_id, month.to_date] }
    end
  end

  def relation_for(metric)
    case metric
    when :archived_items then ArchiveItemUser.all
    when :scrape_requests then Scrape.all
    when :failed_scrapes then Scrape.where(error: true).or(Scrape.where(removed: true))
    when :text_searches then TextSearch.all
    when :image_searches then ImageSearch.all
    when :corpus_downloads then CorpusDownload.all
    end
  end
end
