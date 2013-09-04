require 'rubygems'
require 'open-uri'
require 'logger'

# Gems
require 'bundler'
Bundler.setup
require 'readability'
require 'feedzirra'

module BloggerFeedPusher
  FEED_URL = 'http://digg.com/user/4e1010bf21f3425a98c3c12c4da80735/diggs.rss'
  SLEEP_PERIOD = 5.seconds

  class Article
    READABILITY_OPTIONS = {
      :remove_empty_nodes => false,
      :attributes => %w[src href],
      :tags => %w[br p div img a],
    }

    attr_reader :content, :images
    attr_accessor :logger

    def initialize(feed_entry)
      @feed_entry = feed_entry
      @tags = feed_entry.categories
    end

    def fetch
      logger.info "Fetching article #{@feed_entry.url} ..."
      page_html = open(@feed_entry.url).read
      encoding = page_html.match(/<meta[^>]+charset=([^"]*)[^>]+>/)[1] rescue 'utf-8'

      result = Readability::Document.new(page_html, READABILITY_OPTIONS.merge(:encoding => encoding))

      @content = result.content
      #@images = result.images
    end

    def tags
      @tags
    end

    def title
      @feed_entry.title
    end
  end

  class Pusher
    attr_accessor :logger

    def initialize
    end

    def push_article(article)
      article_hash = {
        :title => article.title,
        :tags => article.tags,
        :content => article.content,
      }

      logger.info("Pushing article: #{article_hash}")
      # TODO: publishing to Blogger

      logger.info("Publishing Done!")
    end
  end

  class Tagger
    def initialize
    end

    def tags
      %w[Путин Сирия экономика].
        map(&:mb_chars).map(&:downcase).map(&:to_s).uniq
    end

    def find_tags(text)
      found_tags = []

      # Search for whole tag in text
      found_tags << tags.reject { |t| text.index(t).nil? }

      min_tag_size = 5

      puts text.split.
        map { |w| w.gsub(/[,.?!=:"']+$/, "") }.
        reject { |w| w.size < min_tag_size }. # ignore small words
        map(&:mb_chars).map(&:downcase).map(&:to_s).
        uniq

      found_tags.flatten
    end
  end

  class Reactor
    attr_reader :logger

    def initialize
      @logger = Logger.new(STDOUT)
      #@last_checked_at = Time.now
      @last_checked_at = 1.hour.ago
    end

    def run
      @pusher = Pusher.new
      @pusher.logger = logger

      logger.info "Feed reactor started!"

      loop do
        begin
          logger.info "Updating feed #{FEED_URL} ..."
          feed = Feedzirra::Feed.fetch_and_parse(FEED_URL)

          if feed == 0
            logger.error "Can't fetch feed"
          else
            feed.entries.reject{ |e| e.published < @last_checked_at }.each do |entry|
              article = Article.new(entry)
              article.logger = logger
              article.fetch

              @pusher.push_article(article)
            end
          end

          @last_checked_at = Time.now
        rescue StandardError => $e
          logger.error $e.message
          logger.error $e.backtrace
        end

        sleep SLEEP_PERIOD
      end
    end
  end
end

#reactor = BloggerFeedPusher::Reactor.new
#reactor.run

tagger = BloggerFeedPusher::Tagger.new

puts tagger.find_tags("Путин решил профинансировать атомную энергетику в Сирии. В небо Сирии поднимуться наши Су-27")
