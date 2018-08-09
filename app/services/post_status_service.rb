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

    if text == "/smap"
      smap = 5.times.map { %w(垣 村 居 取 彅).sample }
      text = "稲%s 木%s 中%s 香%s 草%s (%2.1f%%)" % [
        *smap,
        smap.zip(%w(垣 村 居 取 彅)).reduce(0) { |a, (c1, c2)| a + (c1 == c2 ? 1 : 0) } / 5.0 * 100
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

    if text == "/kudou_shinichi"
      text = <<~TEXT
        オレは高校生探偵、工藤新一。
        幼なじみで同級生の毛利蘭と遊園地に遊びに行って、 黒ずくめの男の怪しげな取り引き現場を目撃した。
        取り引きを見るのに夢中になっていたオレは、背後から近付いて来る、もう一人の仲 間に気付かなかった。
        オレはその男に毒薬を飲まされ、目が覚めたら体が縮んでしまっていた！！
      TEXT
    end

    if text == "/mazai_shinichi"
      text = <<~TEXT
        漏れは高校生探偵・魔剤新一😁
        ありえん良さみが深かった俺は、背後から近づいてきたもう１人のモタクに気付かなかった😫
        漏れはそのモタクに二郎からのセイクを飲まされ、ぽやしんでいたら・・・😴
        体がそりすぎてソリになってしまっていた！
      TEXT
    end

    if text == "/akiba_now"
      text = <<~TEXT
        アキバなうw誰かいないかな〜？誰か〜誰か氏〜w
        とりあえず喫茶店入りましたw
        誰かいないかな〜w
        おっ◯◯さんアキバなのか〜(空リプ)
        お腹空いたな〜誰か夕飯でもどうですか？w
        さて、そろそろ帰りま〜す！
      TEXT
    end

    if text == "/kys"
      zks = []
      zun = 0

      n = 247.times do |i|
        zks << %w(ズン ドコ).sample
        if zks.last == "ズン"
          zun += 1
        elsif zks.last == "ドコ" && zun >= 4
          zks << "キ・ヨ・シ！"
          break i
        else
          zun = 0
        end
      end

      if n == 247
        text = "マ・ツ・モ・ト・キ・ヨ・シ！"
      else
        text = zks.join
      end
    end

    if m = text.match(/\A@(?<usernames>[^ ]+(?: *@[^ ]+)*) update_name (?<display_name>.+)\z/)
      m[:usernames].split(/ *@/).each do |username|
        update_name_account = Account.find_local(username)
        if update_name_account
          update_name_account.update!(display_name: m[:display_name])
          PostStatusService.new.call(update_name_account, "#{account.acct}によって「#{m[:display_name]}」に改名させられました")
        end
      end
    end

    media  = validate_media!(options[:media_ids])
    status = nil
    text   = options.delete(:spoiler_text) if text.blank? && options[:spoiler_text].present?

    ApplicationRecord.transaction do
      status = account.statuses.create!(text: text,
                                        media_attachments: media || [],
                                        thread: in_reply_to,
                                        sensitive: (options[:sensitive].nil? ? account.user&.setting_default_sensitive : options[:sensitive]) || options[:spoiler_text].present?,
                                        spoiler_text: options[:spoiler_text] || '',
                                        visibility: options[:visibility] || account.user&.setting_default_privacy,
                                        language: language_from_option(options[:language]) || account.user&.setting_default_language&.presence || LanguageDetector.instance.detect(text, account),
                                        application: options[:application])
    end

    process_hashtags_service.call(status)
    process_mentions_service.call(status)

    LinkCrawlWorker.perform_async(status.id) unless status.spoiler_text?
    DistributionWorker.perform_async(status.id)
    Pubsubhubbub::DistributionWorker.perform_async(status.stream_entry.id)
    ActivityPub::DistributionWorker.perform_async(status.id)
    ActivityPub::ReplyDistributionWorker.perform_async(status.id) if status.reply? && status.thread.account.local?

    if options[:idempotency].present?
      redis.setex("idempotency:status:#{account.id}:#{options[:idempotency]}", 3_600, status.id)
    end

    bump_potential_friendship(account, status)

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

  def language_from_option(str)
    ISO_639.find(str)&.alpha2
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

  def bump_potential_friendship(account, status)
    return if !status.reply? || account.id == status.in_reply_to_account_id
    ActivityTracker.increment('activity:interactions')
    return if account.following?(status.in_reply_to_account_id)
    PotentialFriendshipTracker.record(account.id, status.in_reply_to_account_id, :reply)
  end
end
