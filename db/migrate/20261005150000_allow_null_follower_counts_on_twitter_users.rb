# X doesn't always return follower counts (e.g. for suspended or restricted accounts).
# A missing count is unknown, not zero, so store it as NULL like `facebook_users.followers_count`.
class AllowNullFollowerCountsOnTwitterUsers < ActiveRecord::Migration[7.2]
  def change
    change_column_null :twitter_users, :followers_count, true
    change_column_null :twitter_users, :following_count, true
  end
end
