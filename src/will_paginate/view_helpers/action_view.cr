# Порт view_helpers/action_view.rb гема — интеграция с action_view.cr
# (~/rails.cr, "crails"). Опциональный файл: НЕ подключается главным
# require'ом will_paginate_cr. Приложение, у которого есть зависимость
# от action_view_cr, подключает его само:
#
#   require "will_paginate_cr"
#   require "will_paginate/view_helpers/action_view"
#
#   abstract class ApplicationController < ActionController::Base
#     include WillPaginate::ActionView
#   end
#
# После этого в ERB-шаблонах — в точности как в Rails:
#
#   <%= will_paginate @posts %>
#   <%= page_entries_info @posts, model: "post" %>
#   <% paginated_section @posts do %> ... <% end %>
#
# ERB в crails компилирует <%= %> в __av_esc: SafeString не экранируется
# (аналог html_safe в геме), обычный String — экранируется, поэтому все
# хелперы здесь возвращают ActionView::SafeString (глобальный).

require "action_view_cr"
require "../view_helpers"
require "../view_helpers/link_renderer"

module WillPaginate
  module ActionView
    include WillPaginate::ViewHelpers

    # Вью-контекст crails: контроллер (ActionController::Base include
    # ActionView::Helpers) уже имеет request — он и строит URL ссылок.
    abstract def request : HTTP::Request

    # Как ActionView-обёртка гема: рендерер подставляется по умолчанию,
    # вывод помечается safe (аналог `output.html_safe`).
    def will_paginate(collection : CollectionMethods, **options) : ::ActionView::SafeString?
      html = super(collection, LinkRenderer, **options)
      html ? ::ActionView::SafeString.new(html) : nil
    end

    def page_entries_info(collection : CollectionMethods, model : String? = nil,
                          html : Bool = true) : ::ActionView::SafeString
      ::ActionView::SafeString.new(super(collection, model, html))
    end

    # Обёртка из гема: ссылки пагинации и до, и после блока контента.
    #
    #   <% paginated_section @posts do %>
    #     <ol id="posts"> ... </ol>
    #   <% end %>
    def paginated_section(collection : CollectionMethods, **options, &) : ::ActionView::SafeString
      pagination = will_paginate(collection, **options)
      content = capture { yield }
      pagination ? ::ActionView::SafeString.new(pagination.raw + content + pagination.raw) : ::ActionView::SafeString.new(content)
    end

    # Порт ActionView::LinkRenderer гема: URL = текущий путь + GET-параметры
    # запроса (страница заменяется/добавляется), смёрженные с options[:params].
    class LinkRenderer < WillPaginate::ViewHelpers::LinkRenderer
      protected def url(page : Int32) : String
        request = @template.not_nil!.as(WillPaginate::ActionView).request

        # merge_get_params: query-параметры любого метода (в crails они
        # доступны всегда), порядок сохраняется, page заменяется на месте
        raw = {} of String => Array(String)
        request.query_params.each { |key, value| raw[key] = [value] }
        query = URI::Params.new(raw)

        # merge_optional_params
        if (extra = @options.not_nil![:params]?).is_a?(Hash(Symbol, String))
          # URI::Params#[]= в 1.21 заменяет значения, сохраняя позицию ключа
          extra.each { |key, value| query[key.to_s] = value }
        end

        # add_current_page_param. Вложенные имена ("foo[page]") гем парсит
        # через Rack; здесь имя ставится как есть (см. PLAN.md).
        query[param_name] = page.to_s

        "#{request.path}?#{query}"
      end
    end
  end
end
