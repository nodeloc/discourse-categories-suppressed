# frozen_string_literal: true

# name: discourse-categories-suppressed
# about: Suppress categories from latest topics page.
# version: 0.1
# url: https://github.com/vinothkannans/discourse-categories-suppressed

after_initialize do
  if TopicQuery.respond_to?(:results_filter_callbacks)
    remove_suppressed_category_topics =
      Proc.new do |list_type, result, user, options|
        category_ids =
          (SiteSetting.categories_suppressed_from_latest.presence || "").split("|").map(&:to_i)

        if category_ids.blank? || list_type != :latest || options[:category] || options[:tags]
          result
        else
          # 获取例外用户组的 topics
          exception_group_ids =
            (SiteSetting.categories_suppressed_exception_groups.presence || "").split("|").map(
              &:to_i
            )

          if exception_group_ids.present?
            # 查找属于例外用户组的用户ID
            exception_user_ids = GroupUser.where(group_id: exception_group_ids).pluck(:user_id)

            if exception_user_ids.present?
              # 排除被压制的分类，但保留例外用户组成员的 topics
              result.where(
                "topics.category_id NOT IN (#{category_ids.join(",")}) OR topics.user_id IN (#{exception_user_ids.join(",")})",
              )
            else
              result.where("topics.category_id NOT IN (#{category_ids.join(",")})")
            end
          else
            result.where("topics.category_id NOT IN (#{category_ids.join(",")})")
          end
        end
      end

    TopicQuery.results_filter_callbacks << remove_suppressed_category_topics
  end
end
