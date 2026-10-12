# Порт lib/will_paginate/active_record.rb гема — интеграция с
# active_record.cr (~/rails.cr). Опциональный файл: НЕ подключается главным
# require'ом will_paginate_cr. Приложение, у которого есть зависимость
# от active_record_cr, подключает его само:
#
#   require "will_paginate_cr"
#   require "will_paginate/active_record"
#
#   class Post < ActiveRecord::Base
#   end
#
#   @posts = Post.paginate(page: params["page"]?, per_page: 10)
#
# Отличие от Ruby-гема (статическая типизация): гем возвращает из
# `paginate` Relation, расширенный на лету RelationMethods (current_page,
# total_entries и магический to_a). `Relation` в Crystal — иммутабельный
# struct: чейн-методы (`where`/`order`/...) строят новый инстанс своим
# конструктором, и состояние, добавленное при reopen, в нём не выживает.
# Поэтому API разделён по состоянию:
#
# - `paginate(page:, per_page:, total_entries:)` — терминальный, сразу
#   материализуется в `WillPaginate::Collection(T)` — массив с данными
#   пагинации, совместимый с вью-хелперами (СOUNT без ORDER/LIMIT/OFFSET
#   или угадывание последней неполной страницы):
#
#   <%= will_paginate @posts %>              <%# работает: Collection(T) %>
#   <%= page_entries_info @posts, model: "post" %>
#
# - `page(num, per_page:)` — stateless-порт `page` гема: ставит нативные
#   поля Relation (offset/limit), поэтому дальше чейн работает как обычно
#   (`Post.page(2, per_page: 10).where(...)`), но итог — обычный Array
#   без current_page/total_entries (вью-хелперам нужен `paginate`).

require "active_record_cr"
require "./per_page"
require "./page_number"
require "./collection"

class ActiveRecord::Base
  # Ruby-гем делает `extend WillPaginate::PerPage` по классам моделей;
  # в Crystal (см. per_page.cr) per-классовое значение задаётся
  # переопределением класс-метода:
  #
  #   class Post < ActiveRecord::Base
  #     def self.per_page : Int32
  #       10
  #     end
  #   end
  #
  # Глобальный дефолт — `WillPaginate.per_page =` (30).
  def self.per_page : Int32
    WillPaginate.per_page
  end

  # Порт Pagination#paginate гема (класс-метод модели):
  #
  #   Post.paginate(page: 2, per_page: 10)                # → Collection(Post)
  #   Post.paginate(page: 2, total_entries: 999)          # без COUNT-запроса
  def self.paginate(page : WillPaginate::PageNumber | Int32 | Int64 | String | Nil = 1,
                    per_page : Int32? = nil, total_entries : Int32? = nil)
    all.paginate(page: page, per_page: per_page, total_entries: total_entries)
  end

  # Порт Pagination#page гема (stateless, см. шапку файла):
  #
  #   Post.page(2, per_page: 10).where(published: true)   # → Relation(Post)
  def self.page(num : WillPaginate::PageNumber | Int32 | Int64 | String | Nil = 1,
                per_page : Int32? = nil) : ::ActiveRecord::Relation(self)
    all.page(num, per_page: per_page)
  end

  # Порт BaseMethods#paginate_by_sql гема: LIMIT/OFFSET дописываются к
  # SQL-строке (postgres-ветка гема), COUNT — подзапросом без ORDER BY:
  #
  #   Post.paginate_by_sql("select * from posts where views > ?",
  #                        args: [5], page: 2, per_page: 10)
  #
  # Колонки результата должны быть колонками модели (как у find_by_sql).
  def self.paginate_by_sql(sql : String, args : Array(DB::Any) = [] of DB::Any,
                           page : WillPaginate::PageNumber | Int32 | Int64 | String | Nil = 1,
                           per_page : Int32? = nil,
                           total_entries : Int32? = nil) : WillPaginate::Collection(self)
    pagenum = WillPaginate.page_number(page.nil? ? 1 : page)
    WillPaginate::Collection(self).create(pagenum, per_page) do |pager|
      # `?` → $n один раз: плейсхолдеры не сдвигаются — LIMIT/OFFSET
      # интерполируются числами, count оборачивает запрос целиком.
      counter = 0
      sanitized = sql.gsub(/\?/) { counter += 1; "$#{counter}" }

      records = [] of self
      data_sql = "#{sanitized} LIMIT #{pager.per_page} OFFSET #{pager.offset}"
      ::ActiveRecord::Base.__session.query(data_sql, args: args) do |rs|
        rs.each do
          records << __from_row_cols(rs, rs.column_names)
        end
      end
      pager.replace(records)

      unless pager.total_entries
        # ORDER BY режется тем же regex, что и в геме
        count_sql = "SELECT COUNT(*) FROM (#{sanitized.sub(/\bORDER\s+BY\s+[\w`,\s.]+$/mi, "")}) AS count_table"
        count = ::ActiveRecord::Base.__session.query_one(count_sql, args: args, as: Int64)
        pager.total_entries = count.to_i32
      end
    end
  end
end

struct ActiveRecord::Relation(T)
  # Порт Pagination#paginate гема для скоупов/чейнов:
  #
  #   Post.where(published: true).order(:id).paginate(page: 2, per_page: 10)
  #
  # Порядок разрешения per_page как в геме: явный аргумент → limit
  # текущего relation → per_page модели → WillPaginate.per_page.
  def paginate(page : WillPaginate::PageNumber | Int32 | Int64 | String | Nil = 1,
               per_page : Int32? = nil, total_entries : Int32? = nil) : WillPaginate::Collection(T)
    per_page_value = per_page || @limit_value.try(&.to_i32) || model.per_page
    pagenum = WillPaginate.page_number(page.nil? ? 1 : page)
    rel = limit(per_page_value).offset(pagenum.to_offset(per_page_value).to_i)
    WillPaginate::Collection(T).create(pagenum, per_page_value, total_entries) do |pager|
      pager.replace(rel.to_a)
      # total_entries ||= count (порт RelationMethods#total_entries):
      # replace уже угадал total для последней неполной страницы.
      pager.total_entries = rel.total_entries unless pager.total_entries
    end
  end

  # Порт RelationMethods#per_page (геттер): per_page пагинированного
  # relation — это его limit.
  def per_page : Int32
    @limit_value.try(&.to_i32) || model.per_page
  end

  # Порт RelationMethods#per_page(n)/limit(n) гема: ставит limit и, если
  # relation уже пагинирован (`page`/`paginate` ставят offset кратным
  # limit), пересчитывает offset под новый per_page — stateless-эквивалент
  # магии гема с запомненным current_page:
  #
  #   Post.page(3, per_page: 10).per_page(5)   # страница 3 по 5 → offset 10
  #
  # offset, не кратный limit (поставлен вручную), не трогается.
  def per_page(value : Int) : Relation(T)
    page = if (lim = @limit_value) && (off = @offset_value) && lim > 0 && off % lim == 0
             off // lim + 1
           end
    rel = limit(value)
    page ? rel.offset((page - 1) * value) : rel
  end

  # Порт RelationMethods#total_entries: COUNT без ORDER BY/LIMIT/OFFSET
  # (при GROUP BY — число групп, как в геме).
  def total_entries : Int32
    result = except(:order, :limit, :offset).count
    result = result.size if result.is_a?(Hash)
    result.to_i32
  end

  # Порт Pagination#page гема — stateless: offset/limit это нативные
  # поля Relation (chain-методы их переносят), поэтому чейн ПОСЛЕ page
  # работает. current_page нигде не хранится — на выходе Array без
  # метаданных пагинации (для вью-хелперов есть `paginate`).
  #
  #   Post.page(2, per_page: 10).order(:id)          # → Relation(Post)
  #   Post.limit(7).page(2)                          # per_page из limit
  #   Post.page                                      # страница 1
  #
  # per_page: явный аргумент → limit текущего relation → per_page модели.
  def page(num : WillPaginate::PageNumber | Int32 | Int64 | String | Nil = 1,
           per_page : Int32? = nil) : Relation(T)
    per_page_value = per_page || @limit_value.try(&.to_i32) || model.per_page
    pagenum = WillPaginate.page_number(num.nil? ? 1 : num)
    offset(pagenum.to_offset(per_page_value).to_i).limit(per_page_value)
  end
end

struct ActiveRecord::CollectionProxy(T)
  # Пагинация ассоциаций (has_many/HABTM/through), как у гема:
  #
  #   post.comments.paginate(page: 2, per_page: 5)
  #
  # Предзагруженная (includes/preload) ассоциация пагинируется в памяти
  # через Array#paginate, БД не трогается.
  def paginate(page : WillPaginate::PageNumber | Int32 | Int64 | String | Nil = 1,
               per_page : Int32? = nil, total_entries : Int32? = nil)
    if loaded = @loaded
      loaded.paginate(page: page, per_page: per_page, total_entries: total_entries)
    else
      scope.paginate(page: page, per_page: per_page, total_entries: total_entries)
    end
  end

  # Stateless-`page` на ассоциации (как where/order прокси — через scope):
  #
  #   post.comments.order(:id).page(2, per_page: 5)   # → Relation(Comment)
  def page(num : WillPaginate::PageNumber | Int32 | Int64 | String | Nil = 1,
           per_page : Int32? = nil) : Relation(T)
    scope.page(num, per_page: per_page)
  end
end
