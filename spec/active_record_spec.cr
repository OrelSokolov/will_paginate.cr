# Интеграционная спека will_paginate.cr × active_record.cr (crails).
# Отдельная БД crails_wp_test (создаётся вручную, как crails_ar_test
# у самого active_record.cr); таблицы/фикстуры — как в spec/rolify.cr:
# CREATE TABLE IF NOT EXISTS + TRUNCATE при старте.

require "spec"
require "../src/will_paginate_cr"
require "../src/will_paginate/active_record"

TEST_URL = ENV["WP_TEST_URL"]? ||
           "postgres://root@/crails_wp_test?host=/var/run/postgresql"

class Post < ActiveRecord::Base
  has_many :comments
end

class Comment < ActiveRecord::Base
  belongs_to :post
end

# вью-контекст для page_entries_info (хелперы — instance-методы модуля)
class WPView
  include WillPaginate::ViewHelpers
end

# per-классовый per_page (переопределение класс-метода, см. integration)
class TenPosts < ActiveRecord::Base
  set_table_name "posts"

  def self.per_page : Int32
    10
  end
end

describe "will_paginate × active_record" do
  before_all do
    ActiveRecord::Base.establish_connection(TEST_URL)
    conn = ActiveRecord::Base.__session
    conn.exec(%(CREATE TABLE IF NOT EXISTS posts (
      id         bigserial PRIMARY KEY,
      title      varchar(255),
      views      bigint NOT NULL DEFAULT 0,
      created_at timestamp,
      updated_at timestamp
    )))
    conn.exec(%(CREATE TABLE IF NOT EXISTS comments (
      id         bigserial PRIMARY KEY,
      post_id    bigint NOT NULL REFERENCES posts(id),
      body       text,
      created_at timestamp,
      updated_at timestamp
    )))
    conn.exec(%(TRUNCATE comments, posts RESTART IDENTITY CASCADE))
    26.times do |i|
      conn.exec(%(INSERT INTO posts (title, views) VALUES ($1, $2)),
        args: ["Post ##{i + 1}", i + 1])
    end
    # 12 комментариев у поста 1, по одному у постов 2..5
    12.times { |i| conn.exec(%(INSERT INTO comments (post_id, body) VALUES (1, $1)), args: ["c#{i + 1}"]) }
    (2..5).each { |pid| conn.exec(%(INSERT INTO comments (post_id, body) VALUES ($1, $2)), args: [pid, "c#{pid}"]) }
  end

  describe "Post.paginate (класс-метод)" do
    it "страница 1 с явным per_page" do
      posts = Post.order(:id).paginate(page: 1, per_page: 10)
      posts.should be_a(WillPaginate::Collection(Post))
      posts.size.should eq(10)
      posts.map(&.id).should eq((1..10).to_a)
      posts.current_page.to_i.should eq(1)
      posts.per_page.should eq(10)
      posts.total_entries.should eq(26) # COUNT-запрос
      posts.total_pages.should eq(3)
      posts.previous_page.should be_nil
      posts.next_page.should eq(2)
    end

    it "средняя и последняя страница" do
      Post.order(:id).paginate(page: 2, per_page: 10).map(&.id).should eq((11..20).to_a)
      last = Post.order(:id).paginate(page: 3, per_page: 10)
      last.map(&.id).should eq((21..26).to_a)
      last.total_entries.should eq(26)
      last.next_page.should be_nil
    end

    it "страница за пределами — out_of_bounds?" do
      oob = Post.order(:id).paginate(page: 4, per_page: 10)
      oob.should be_empty
      oob.out_of_bounds?.should be_true
      oob.total_entries.should eq(26)
    end

    it "page по умолчанию = 1, page из строки" do
      Post.order(:id).paginate(per_page: 5).map(&.id).should eq((1..5).to_a)
      Post.order(:id).paginate(page: "3", per_page: 10).map(&.id).should eq((21..26).to_a)
    end

    it "невалидная страница поднимает InvalidPage" do
      expect_raises(WillPaginate::InvalidPage, "invalid page: 0") do
        Post.paginate(page: 0, per_page: 10)
      end
    end

    it "total_entries явно — без COUNT-запроса" do
      posts = Post.order(:id).paginate(page: 1, per_page: 10, total_entries: 999)
      posts.total_entries.should eq(999)
      posts.total_pages.should eq(100)
    end
  end

  describe "чейны (Relation#paginate)" do
    it "where + order + paginate" do
      posts = Post.where("views > ?", 5).order(:id).paginate(page: 2, per_page: 5)
      posts.map(&.views).should eq((11..15).to_a.map(&.to_i64))
      posts.total_entries.should eq(21) # views 6..26
    end

    it "limit relation задаёт per_page (как `per_page` гема)" do
      posts = Post.order(:id).limit(7).paginate(page: 2)
      posts.per_page.should eq(7)
      posts.map(&.id).should eq((8..14).to_a)
    end

    it "per_page модели (переопределение класс-метода)" do
      posts = TenPosts.order(:id).paginate(page: 2)
      posts.per_page.should eq(10)
      posts.map(&.id).should eq((11..20).to_a)
    end

    it "глобальный WillPaginate.per_page — дефолт" do
      begin
        WillPaginate.per_page = 30
        posts = Post.order(:id).paginate
        posts.per_page.should eq(30)
        posts.size.should eq(26)          # всё на одной странице
        posts.total_entries.should eq(26) # угадано без COUNT (size < per_page)
      ensure
        WillPaginate.per_page = 30
      end
    end
  end

  describe "ассоциации (CollectionProxy#paginate)" do
    it "has_many через БД" do
      post = Post.find(1)
      comments = post.comments.order(:id).paginate(page: 2, per_page: 5)
      comments.should be_a(WillPaginate::Collection(Comment))
      comments.size.should eq(5)
      comments.total_entries.should eq(12)
      comments.total_pages.should eq(3)
    end

    it "предзагруженная ассоциация пагинируется в памяти" do
      post = Post.includes(:comments).where(id: 1).first.not_nil!
      comments = post.comments.paginate(page: 3, per_page: 5)
      comments.size.should eq(2)
      comments.total_entries.should eq(12)
    end
  end

  describe "page (stateless, без метаданных)" do
    it "ставит offset/limit и возвращает Relation" do
      rel = Post.order(:id).page(2, per_page: 10)
      rel.should be_a(ActiveRecord::Relation(Post))
      rel.map(&.id).should eq((11..20).to_a)
    end

    it "чейн ПОСЛЕ page работает (состояние не нужно)" do
      posts = Post.page(2, per_page: 10).where("views > ?", 5).order(:id).to_a
      posts.map(&.id).should eq((16..25).to_a) # views 6..26, страница 2
    end

    it "per_page из limit relation / модели, page по умолчанию = 1" do
      Post.limit(7).order(:id).page(2).map(&.id).should eq((8..14).to_a)
      TenPosts.order(:id).page(2).map(&.id).should eq((11..20).to_a)
      Post.order(:id).page.map(&.id).should eq((1..26).to_a)
    end

    it "страница из строки, невалидная страница поднимает InvalidPage" do
      Post.order(:id).page("2", per_page: 10).map(&.id).should eq((11..20).to_a)
      expect_raises(WillPaginate::InvalidPage, "invalid page: 0") do
        Post.page(0, per_page: 10)
      end
    end

    it "класс-метод и ассоциация" do
      Post.page(3, per_page: 10).order(:id).map(&.id).should eq((21..26).to_a)
      Post.find(1).comments.order(:id).page(2, per_page: 5).map(&.body).should eq(%w[c6 c7 c8 c9 c10])
    end
  end

  describe "per_page / total_entries на Relation" do
    it "per_page-геттер: limit relation или дефолт" do
      Post.limit(7).per_page.should eq(7)
      Post.all.per_page.should eq(WillPaginate.per_page)
      TenPosts.all.per_page.should eq(10)
    end

    it "per_page-сеттер пересчитывает offset пагинированного relation" do
      Post.page(3, per_page: 10).order(:id).per_page(5).map(&.id).should eq((11..15).to_a)
    end

    it "per_page-сеттер не трогает произвольный offset" do
      Post.offset(5).limit(10).order(:id).per_page(10).map(&.id).should eq((6..15).to_a)
    end

    it "total_entries — COUNT без влияния limit/offset" do
      Post.where("views > ?", 5).total_entries.should eq(21)
      Post.limit(3).offset(2).total_entries.should eq(26)
    end
  end

  describe "paginate_by_sql" do
    it "дописывает LIMIT/OFFSET, считает COUNT-подзапросом" do
      posts = Post.paginate_by_sql("select * from posts where views > ? order by id",
        args: [5_i64], page: 2, per_page: 10)
      posts.should be_a(WillPaginate::Collection(Post))
      posts.map(&.id).should eq((16..25).to_a)
      posts.total_entries.should eq(21)
      posts.total_pages.should eq(3)
    end

    it "страница 1 по умолчанию" do
      posts = Post.paginate_by_sql("select * from posts order by id", per_page: 5)
      posts.map(&.id).should eq((1..5).to_a)
      posts.total_entries.should eq(26)
    end
  end

  describe "совместимость с вью-хелперами" do
    it "page_entries_info по AR-коллекции" do
      WillPaginate::I18n.store_translations("en",
        {"models" => {"post" => {"zero" => "posts", "one" => "post", "other" => "posts"}}} of String => Hash(String, Hash(String, String)))
      posts = Post.order(:id).paginate(page: 2, per_page: 10)
      view = WPView.new
      info = view.page_entries_info(posts, model: "post")
      info.should eq("Displaying posts <b>11&nbsp;-&nbsp;20</b> of <b>26</b> in total")
    end
  end
end
