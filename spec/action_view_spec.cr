# Интеграция с action_view.cr (crails, ~/rails.cr): API как в оракуле —
# `<%= will_paginate @posts %>` без явного рендерера. Шаблон компилируется
# тем же template_processor'ом, что и вьюхи crails; вывод сравнивается
# байт-в-байт с oracle/expected.yml (снятым с настоящего will_paginate 4.0.1).

require "spec"
require "http"
require "../src/will_paginate_cr"
require "../src/will_paginate/view_helpers/action_view"

AV_EXPECTED = begin
  hash = {} of String => String
  File.read("#{__DIR__}/../oracle/expected.yml").each_line do |line|
    if line.includes?('\t')
      id, value = line.split('\t', 2)
      hash[id] = value.chomp
    end
  end
  hash
end

# Вью-контекст как в crails: ApplicationController include ActionView::Helpers
# (контроллер = вью, request доступен рендереру для URL).
class AVPostsView
  include ActionView::Helpers
  include WillPaginate::ActionView

  getter request : HTTP::Request
  property posts : WillPaginate::Collection(Int32)

  def initialize(path : String)
    @request = HTTP::Request.new("GET", path)
    @posts = WillPaginate::Collection(Int32).new(1, 10, 0)
  end

  compile_template("render_posts", "spec/erb/posts_index.html.erb")
end

# page_entries_info-шаблон (model обязателен: см. отличия в PLAN.md)
class AVInfoView
  include ActionView::Helpers
  include WillPaginate::ActionView

  getter request : HTTP::Request
  property posts : WillPaginate::Collection(Int32)

  def initialize(path : String)
    @request = HTTP::Request.new("GET", path)
    @posts = WillPaginate::Collection(Int32).new(1, 10, 0)
  end

  compile_template("render_info", "spec/erb/posts_info.html.erb")
  compile_template("render_section", "spec/erb/posts_section.html.erb")
end

describe "WillPaginate::ActionView (crails ERB)" do
  it "will_paginate в ERB — байт-в-байт с оракулом (wp_gaps)" do
    view = AVPostsView.new("/foo")
    view.posts = (1..300).to_a.paginate(page: 15, per_page: 10)
    # Экранирование SafeString не применяется: &#8592;/&hellip; остаются
    # сырыми; URL строится из request.path — как TestRenderer оракула.
    # Завершающий \n — текст шаблона после %> (trim только у <% %>).
    view.render_posts.raw.should eq("<h1>Posts</h1>\n" + AV_EXPECTED["wp_gaps"] + "\n")
  end

  it "без второй страницы рендерит nil (как в оракуле)" do
    view = AVPostsView.new("/foo")
    view.posts = (1..5).to_a.paginate(per_page: 10)
    view.render_posts.raw.should eq("<h1>Posts</h1>\n\n")
  end

  it "GET-параметры сохраняются, page заменяется на месте" do
    view = AVPostsView.new("/foo?tag=crystal&page=15&extra=1")
    view.posts = (1..300).to_a.paginate(page: 15, per_page: 10)
    html = view.render_posts.raw
    # & в атрибуте экранируется в &amp; — как CGI.escapeHTML в самом геме
    html.should contain(%(href="/foo?tag=crystal&amp;page=1&amp;extra=1"))
    html.should contain(%(href="/foo?tag=crystal&amp;page=16&amp;extra=1"))
    # текущая страница не ссылка
    html.should contain(%(aria-current="page">15<))
  end

  it "page добавляется в конец, если его не было в query" do
    view = AVPostsView.new("/foo?tag=crystal")
    view.posts = (1..300).to_a.paginate(page: 2, per_page: 10)
    view.render_posts.raw.should contain(%(href="/foo?tag=crystal&amp;page=3"))
  end

  it "page_entries_info в ERB не экранируется (<b> сырые)" do
    view = AVInfoView.new("/foo")
    view.posts = WillPaginate::Collection(Int32).create(2, 10, 26) { |p| p.replace((11..20).to_a) }
    WillPaginate::I18n.store_translations("en",
      {"models" => {"entry" => {"zero" => "entries", "one" => "entry", "other" => "entries"}}} of String => Hash(String, Hash(String, String)))
    view.render_info.raw.should eq(AV_EXPECTED["pei_multi_html"] + "\n")
  end

  it "paginated_section рендерит пагинацию до и после блока" do
    view = AVInfoView.new("/foo")
    view.posts = (1..26).to_a.paginate(page: 2, per_page: 10)
    html = view.render_section.raw
    pagination = view.will_paginate(view.posts).not_nil!.raw
    # контент блока — как в Erubi: с \n после do-тега (trim только у <% %>)
    html.should eq(pagination + "\n<ol>posts</ol>\n" + pagination)
    html.should start_with("<div role=\"navigation\"")
    html.should end_with("</div>")
  end

  it "options пробрасываются: page_links: false" do
    view = AVPostsView.new("/foo?page=15")
    view.posts = (1..300).to_a.paginate(page: 15, per_page: 10)
    html = view.will_paginate(view.posts, page_links: false).not_nil!.raw
    html.scan(/href=/).size.should eq(2) # только prev/next
  end
end
