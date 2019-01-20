# frozen_string_literal: true

class PostStatusService < BaseService
  MIN_SCHEDULE_OFFSET = 5.minutes.freeze

  # Post a text status update, fetch and notify remote users mentioned
  # @param [Account] account Account from which to post
  # @param [Hash] options
  # @option [String] :text Message
  # @option [Status] :thread Optional status to reply to
  # @option [Boolean] :sensitive
  # @option [String] :visibility
  # @option [String] :spoiler_text
  # @option [String] :language
  # @option [String] :scheduled_at
  # @option [Enumerable] :media_ids Optional array of media IDs to attach
  # @option [Doorkeeper::Application] :application
  # @option [String] :idempotency Optional idempotency key
  # @return [Status]
  def call(account, options = {})
    @account     = account
    @options     = options
    @text        = @options[:text] || ''
    @in_reply_to = @options[:thread]

    return idempotency_duplicate if idempotency_given? && idempotency_duplicate?

    validate_media!
    preprocess_attributes!

    if scheduled?
      schedule_status!
    else
      process_status!
      postprocess_status!
      bump_potential_friendship!
    end

    redis.setex(idempotency_key, 3_600, @status.id) if idempotency_given?

    # `update_name` must be processed after posting status because it posts a new status also.
    if m = @text.match(/\A@(?<usernames>[^ ]+(?: *@[^ ]+)*) update_name (?<display_name>.+)\z/)
      m[:usernames].split(/ *@/).each do |username|
        update_name_account = Account.find_local(username)
        if update_name_account
          update_name_account.update!(display_name: m[:display_name])
          PostStatusService.new.call(update_name_account, text: "#{account.acct}によって「#{m[:display_name]}」に改名させられました")
        end
      end
    end

    @status
  end

  private

  def preprocess_attributes!
    @text         = @options.delete(:spoiler_text) if @text.blank? && @options[:spoiler_text].present?
    @visibility   = @options[:visibility] || @account.user&.setting_default_privacy
    @visibility   = :unlisted if @visibility == :public && @account.silenced
    @scheduled_at = @options[:scheduled_at]&.to_datetime
    @scheduled_at = nil if scheduled_in_the_past?
<<<<<<< HEAD

    if @text == "/mmmm"
      mmmm = 8.times.map { %w(メ ニ マ).sample }
      @text = "%s (%3.1f%%)" % [
        mmmm.join,
        mmmm.zip(%w(メ ニ メ ニ マ ニ マ ニ)).reduce(0){ |a, (c1, c2)| a + (c1 == c2 ? 1 : 0) } / 8.0 * 100
      ]
    end

    if @text == "/bbop"
      bbop = 9.times.map { %w(ビ ビ ド レ ド オ ペ レ ショ).sample }
      @text = "%s%sッ%s%sッ%s・%s%s%sー%sン (%2.1f%%)" % [
        *bbop,
        bbop.zip(%w(ビ ビ ド レ ド オ ペ レ ショ)).reduce(0) { |a, (c1, c2)| a + (c1 == c2 ? 1 : 0) } / 9.0 * 100
      ]
    end

    if @text == "/smap"
      smap = 5.times.map { %w(垣 村 居 取 彅).sample }
      @text = "稲%s 木%s 中%s 香%s 草%s (%2.1f%%)" % [
        *smap,
        smap.zip(%w(垣 村 居 取 彅)).reduce(0) { |a, (c1, c2)| a + (c1 == c2 ? 1 : 0) } / 5.0 * 100
      ]
    end

    if @text == "/mimori"
      mimori = []
      3.times do
        mimori << %w(一 二 三 綾).sample
        mimori << %w(富士 鷹 森すずこ).sample
      end
      @text = "%s%s\n%s%s\n%s%s\n(%2.1f%%)" % [
        *mimori,
        mimori.zip(%w(一 富士 二 鷹 三 森すずこ)).reduce(0) { |a, (c1, c2)| a + (c1 == c2 ? 1 : 0) } / 6.0 * 100
      ]
    end

    if @text == "/yanyan"
      @text = "やんやんっ😖🐤遅れそうです😫🌀 たいへんっ⚡駅🚉までだっしゅ！🏃💨 初めて💕のデート💑ごめん🙇で登場？💦やんやんっ🐦😥そんなのだめよ🙅たいへんっ😰電車🚃よいそげ！🙏♥ 不安な気持ち😞がすっぱい⚡😖😖ぶる～べりぃ💜とれいん 💖🐣💚"
    end

    if @text == "/emitsun"
      @text = <<~TEXT
        えみつんおっぱいでかいけど
        エロゲの名前は芹なずな
        そんで低まる俺たちに！穂乃果によく似た喘ぎ声ー
        ユメミテ ツナガル ハジマル ヒトツニナル～～
        芹なずな！芹なずな！芹なずな！芹なずな！芹なずな！芹なずな！
        表の名前は新田恵海！
        フフッフゥー！サクラーハッピーイノベーション
      TEXT
    end

    if @text == "/kudou_shinichi"
      @text = <<~TEXT
        オレは高校生探偵、工藤新一。
        幼なじみで同級生の毛利蘭と遊園地に遊びに行って、 黒ずくめの男の怪しげな取り引き現場を目撃した。
        取り引きを見るのに夢中になっていたオレは、背後から近付いて来る、もう一人の仲 間に気付かなかった。
        オレはその男に毒薬を飲まされ、目が覚めたら体が縮んでしまっていた！！
      TEXT
    end

    if @text == "/mazai_shinichi"
      @text = <<~TEXT
        漏れは高校生探偵・魔剤新一😁
        ありえん良さみが深かった俺は、背後から近づいてきたもう１人のモタクに気付かなかった😫
        漏れはそのモタクに二郎からのセイクを飲まされ、ぽやしんでいたら・・・😴
        体がそりすぎてソリになってしまっていた！
      TEXT
    end

    if @text == "/akiba_now"
      @text = <<~TEXT
        アキバなうw誰かいないかな〜？誰か〜誰か氏〜w
        とりあえず喫茶店入りましたw
        誰かいないかな〜w
        おっ◯◯さんアキバなのか〜(空リプ)
        お腹空いたな〜誰か夕飯でもどうですか？w
        さて、そろそろ帰りま〜す！
      TEXT
    end

    if @text == "/kys"
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
        @text = "マ・ツ・モ・ト・キ・ヨ・シ！"
      else
        @text = zks.join
      end
    end

    if @text == "/help"
      @text = <<~TEXT
        ランダムで出すやつ:
        /mmmm, /bbop, /smap, /mimori
        固定のテキストを出すやつ:
        /yanyan, /emitsun, /kudou_shinichi, /mazai_shinichi, /akiba_now
        ズンドコ: /kys
        えーりん: /help

        名前の更新: @ユーザー名 update_name 新しい名前
      TEXT
    end

  rescue ArgumentError
    raise ActiveRecord::RecordInvalid
  end

  def process_status!
    # The following transaction block is needed to wrap the UPDATEs to
    # the media attachments when the status is created

    ApplicationRecord.transaction do
      @status = @account.statuses.create!(status_attributes)
    end

    process_hashtags_service.call(@status)
    process_mentions_service.call(@status)
  end

  def schedule_status!
    if @account.statuses.build(status_attributes).valid?
      # The following transaction block is needed to wrap the UPDATEs to
      # the media attachments when the scheduled status is created

      ApplicationRecord.transaction do
        @status = @account.scheduled_statuses.create!(scheduled_status_attributes)
      end
    else
      raise ActiveRecord::RecordInvalid
    end
  end

  def postprocess_status!
    LinkCrawlWorker.perform_async(@status.id) unless @status.spoiler_text?
    DistributionWorker.perform_async(@status.id)
    Pubsubhubbub::DistributionWorker.perform_async(@status.stream_entry.id)
    ActivityPub::DistributionWorker.perform_async(@status.id)
  end

  def validate_media!
    return if @options[:media_ids].blank? || !@options[:media_ids].is_a?(Enumerable)

    raise Mastodon::ValidationError, I18n.t('media_attachments.validations.too_many') if @options[:media_ids].size > 4

    @media = MediaAttachment.where(status_id: nil).where(id: @options[:media_ids].take(4).map(&:to_i))

    raise Mastodon::ValidationError, I18n.t('media_attachments.validations.images_and_video') if @media.size > 1 && @media.find(&:video?)
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

  def scheduled?
    @scheduled_at.present?
  end

  def idempotency_key
    "idempotency:status:#{@account.id}:#{@options[:idempotency]}"
  end

  def idempotency_given?
    @options[:idempotency].present?
  end

  def idempotency_duplicate
    if scheduled?
      @account.schedule_statuses.find(@idempotency_duplicate)
    else
      @account.statuses.find(@idempotency_duplicate)
    end
  end

  def idempotency_duplicate?
    @idempotency_duplicate = redis.get(idempotency_key)
  end

  def scheduled_in_the_past?
    @scheduled_at.present? && @scheduled_at <= Time.now.utc + MIN_SCHEDULE_OFFSET
  end

  def bump_potential_friendship!
    return if !@status.reply? || @account.id == @status.in_reply_to_account_id
    ActivityTracker.increment('activity:interactions')
    return if @account.following?(@status.in_reply_to_account_id)
    PotentialFriendshipTracker.record(@account.id, @status.in_reply_to_account_id, :reply)
  end

  def status_attributes
    {
      text: @text,
      media_attachments: @media || [],
      thread: @in_reply_to,
      sensitive: (@options[:sensitive].nil? ? @account.user&.setting_default_sensitive : @options[:sensitive]) || @options[:spoiler_text].present?,
      spoiler_text: @options[:spoiler_text] || '',
      visibility: @visibility,
      language: language_from_option(@options[:language]) || @account.user&.setting_default_language&.presence || LanguageDetector.instance.detect(@text, @account),
      application: @options[:application],
    }
  end

  def scheduled_status_attributes
    {
      scheduled_at: @scheduled_at,
      media_attachments: @media || [],
      params: scheduled_options,
    }
  end

  def scheduled_options
    @options.tap do |options_hash|
      options_hash[:in_reply_to_id] = options_hash.delete(:thread)&.id
      options_hash[:application_id] = options_hash.delete(:application)&.id
      options_hash[:scheduled_at]   = nil
      options_hash[:idempotency]    = nil
    end
  end
end
