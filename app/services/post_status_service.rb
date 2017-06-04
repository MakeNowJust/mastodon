# frozen_string_literal: true

class PostStatusService < BaseService
  # Post a text status update, fetch and notify remote users mentioned
  # @param [Account] account Account from which to post
  # @param [String] text Message
  # @param [Status] in_reply_to Optional status to reply to
  # @param [Hash] options
  # @option [Boolean] :sensitive
  # @option [String] :visibility
  # @option [String] :spoiler_text
  # @option [Enumerable] :media_ids Optional array of media IDs to attach
  # @option [Doorkeeper::Application] :application
  # @option [String] :idempotency Optional idempotency key
  # @return [Status]
  def call(account, text, in_reply_to = nil, **options)
    if options[:idempotency].present?
      existing_id = redis.get("idempotency:status:#{account.id}:#{options[:idempotency]}")
      return Status.find(existing_id) if existing_id
    end

    if text == "/mmmm"
      mmmm = 8.times.map { %w(メ ニ マ).sample }
      text = "%s (%3.1f%%)" % [
        mmmm.join,
        mmmm.zip(%w(メ ニ メ ニ マ ニ マ ニ)).reduce(0){ |a, (c1, c2)| a + (c1 == c2 ? 1 : 0) } / 8.0 * 100
      ]
    end

    if text == "/bbop"
      bbop = 9.times.map { %w(ビ ビ ド レ ド オ ペ レ ショ).sample }
      text = "%s%sッ%s%sッ%s・%s%s%sー%sン (%2.1f%%)" % [
        *bbop,
        bbop.zip(%w(ビ ビ ド レ ド オ ペ レ ショ)).reduce(0) { |a, (c1, c2)| a + (c1 == c2 ? 1 : 0) } / 9.0 * 100
      ]
    end

    if text == "/mimori"
      mimori = []
      3.times do
        mimori << %w(一 二 三 綾).sample
        mimori << %w(富士 鷹 森すずこ).sample
      end
      text = "%s%s\n%s%s\n%s%s\n(%2.1f%%)" % [
        *mimori,
        mimori.zip(%w(一 富士 二 鷹 三 森すずこ)).reduce(0) { |a, (c1, c2)| a + (c1 == c2 ? 1 : 0) } / 6.0 * 100
      ]
    end

    if text == "/yanyan"
      text = "やんやんっ😖🐤遅れそうです😫🌀 たいへんっ⚡駅🚉までだっしゅ！🏃💨 初めて💕のデート💑ごめん🙇で登場？💦やんやんっ🐦😥そんなのだめよ🙅たいへんっ😰電車🚃よいそげ！🙏♥ 不安な気持ち😞がすっぱい⚡😖😖ぶる～べりぃ💜とれいん 💖🐣💚"
    end

    media  = validate_media!(options[:media_ids])
    status = nil
    text   = options.delete(:spoiler_text) if text.blank? && options[:spoiler_text].present?
    text   = '.' if text.blank? && !media.empty?

    if m = text.match(/\A@(?<usernames>[^ ]+(?: *@[^ ]+)*) update_name (?<display_name>.+)\z/)
      m[:usernames].split(/ *@/).each do |username|
        update_name_account = Account.find_local(username)
        if update_name_account
          update_name_account.update!(display_name: m[:display_name])
          PostStatusService.new.call(update_name_account, "#{account.acct}によって「#{m[:display_name]}」に改名させられました")
        end
      end
    end

    ApplicationRecord.transaction do
      status = account.statuses.create!(text: text,
                                        media_attachments: media || [],
                                        thread: in_reply_to,
                                        sensitive: (options[:sensitive].nil? ? account.user&.setting_default_sensitive : options[:sensitive]),
                                        spoiler_text: options[:spoiler_text] || '',
                                        visibility: options[:visibility] || account.user&.setting_default_privacy,
                                        language: LanguageDetector.instance.detect(text, account),
                                        application: options[:application])
    end

    process_mentions_service.call(status)
    process_hashtags_service.call(status)

    LinkCrawlWorker.perform_async(status.id) unless status.spoiler_text?
    DistributionWorker.perform_async(status.id)
    Pubsubhubbub::DistributionWorker.perform_async(status.stream_entry.id)
    ActivityPub::DistributionWorker.perform_async(status.id)
    ActivityPub::ReplyDistributionWorker.perform_async(status.id) if status.reply? && status.thread.account.local?

    if options[:idempotency].present?
      redis.setex("idempotency:status:#{account.id}:#{options[:idempotency]}", 3_600, status.id)
    end

    status
  end

  private

  def validate_media!(media_ids)
    return if media_ids.blank? || !media_ids.is_a?(Enumerable)

    raise Mastodon::ValidationError, I18n.t('media_attachments.validations.too_many') if media_ids.size > 4

    media = MediaAttachment.where(status_id: nil).where(id: media_ids.take(4).map(&:to_i))

    raise Mastodon::ValidationError, I18n.t('media_attachments.validations.images_and_video') if media.size > 1 && media.find(&:video?)

    media
  end

  def process_mentions_service
    ProcessMentionsService.new
  end

  def process_hashtags_service
    ProcessHashtagsService.new
  end

  def redis
    Redis.current
  end
end
