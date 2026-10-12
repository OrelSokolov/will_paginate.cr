require "./core_ext"
require "./deprecation"
require "./i18n"

module WillPaginate
  # = Will Paginate view helpers
  #
  # Главный хелпер — `will_paginate`: рендерит ссылки пагинации для
  # коллекции. Сам хелпер — тонкая обёртка вокруг LinkRenderer.
  module ViewHelpers
    alias OptionValue = Nil | Bool | Int32 | String | Symbol | Hash(Symbol, String)

    # Писать в этот хэш, чтобы переопределить дефолты глобально:
    #
    #   WillPaginate::ViewHelpers.pagination_options[:page_links] = false
    def self.pagination_options : Deprecation::Hash(Symbol, OptionValue)
      @@pagination_options
    end

    @@pagination_options : Deprecation::Hash(Symbol, OptionValue) = begin
      options = Deprecation::Hash(Symbol, OptionValue).new
      options[:class] = "pagination"
      options[:previous_label] = nil
      options[:next_label] = nil
      options[:inner_window] = 4    # ссылки вокруг текущей страницы
      options[:outer_window] = 1    # ссылки в начале и конце
      options[:link_separator] = " " # один пробел дружелюбен к паукам
      options[:param_name] = :page
      options[:params] = nil
      options[:page_links] = true
      options[:container] = true
      options
    end

    # В Ruby деприкейшн-сообщение для лейблов печатается только под Rails;
    # здесь блок всегда возвращает nil (без warning), 1:1 по поведению.
    @@pagination_options.deprecate_key(:previous_label, :next_label) { |_key, _value| nil }
    @@pagination_options.deprecate_key(:renderer) { |key, _value|
      "pagination_options[#{key.inspect}] shouldn't be set globally"
    }

    include WillPaginate::I18n

    # HTML со ссылками страниц для объекта, совместимого с
    # WillPaginate::Collection. Если страниц не больше одной — nil.
    #
    # ==== Опции
    # * +class+ — CSS-класс DIV (default: "pagination")
    # * +previous_label+ — default: "&#8592; Previous"
    # * +next_label+ — default: "Next &#8594;"
    # * +inner_window+ — ссылок вокруг текущей страницы (default: 4)
    # * +outer_window+ — ссылок вокруг первой и последней (default: 1)
    # * +link_separator+ — разделитель элементов (default: пробел)
    # * +param_name+ — имя параметра страницы в URL (default: :page)
    # * +page_links+ — false: только previous/next (default: true)
    # * +container+ — рендерить ли DIV-контейнер (default: true)
    # * +renderer+ — класс или экземпляр рендерера (default: отсутствует —
    #   ArgumentError, как в базовом модуле гема; интеграции подставляют
    #   свой LinkRenderer)
    #
    # Неопознанные опции становятся HTML-атрибутами контейнера:
    #
    #   will_paginate(@posts, style: "color:blue")
    #   #-> <div class="pagination" style="color:blue"> ... </div>
    #
    # (в Crystal +renderer+ — отдельный позиционный аргумент, а не ключ
    # хэша опций: в типизированном хэше нельзя хранить классы)
    def will_paginate(collection : CollectionMethods,
                      renderer : LinkRendererBase.class | LinkRendererBase | Nil = nil,
                      **options) : String?
      return nil unless collection.total_pages > 1

      merged = {} of Symbol => OptionValue
      ViewHelpers.pagination_options.each { |key, value| merged[key] = value }
      options.each { |key, value| merged[key] = value }

      merged[:previous_label] ||= will_paginate_translate(:previous_label) { "&#8592; Previous" }
      merged[:next_label] ||= will_paginate_translate(:next_label) { "Next &#8594;" }

      render = case renderer
               when LinkRendererBase.class then renderer.new
               when LinkRendererBase then renderer
               else
                 raise ArgumentError.new(":renderer not specified")
               end
      render.prepare collection, merged, self
      render.to_html
    end

    # Сообщение о числе показанных записей от общего числа:
    #
    #   page_entries_info(@posts)
    #   #-> Displaying posts 6 - 12 of 26 in total
    #
    # Вывод по умолчанию содержит HTML; передайте html: false для текста.
    # model — имя модели (Ruby выводит его из collection.first.class;
    # статическая типизация — передавайте явно, default: "entry").
    def page_entries_info(collection : CollectionMethods, model : String? = nil,
                          html : Bool = true) : String
      model ||= "entry"
      model_key = WillPaginate.underscore(model)

      if html
        b, eb, sp, html_key = "<b>", "</b>", "&nbsp;", "_html"
      else
        b, eb, sp, html_key = "", "", " ", ""
      end

      model_count = collection.total_pages > 1 ? 5 : collection.size
      model_name = will_paginate_translate(["models.#{model_key}"], {"count" => model_count})

      if collection.total_pages < 2
        keys = ["#{model_key}.page_entries_info.single_page#{html_key}",
                "page_entries_info.single_page#{html_key}"]
        count = collection.total_entries
        will_paginate_translate(keys, {"count" => count, "model" => model_name}) do |_key|
          case count
          when 0 then "No #{model_name} found"
          when 1 then "Displaying #{b}1#{eb} #{model_name}"
          else        "Displaying #{b}all#{sp}#{count}#{eb} #{model_name}"
          end
        end
      else
        keys = ["#{model_key}.page_entries_info.multi_page#{html_key}",
                "page_entries_info.multi_page#{html_key}"]
        from = collection.offset + 1
        to = collection.offset + collection.size
        will_paginate_translate(keys,
          {"model" => model_name, "count" => collection.total_entries,
           "from" => from, "to" => to}) do |_key|
          "Displaying #{model_name} #{b}#{from}#{sp}-#{sp}#{to}#{eb} of #{b}#{collection.total_entries}#{eb} in total"
        end
      end
    end
  end
end
