require "html"

module WillPaginate
  module ViewHelpers
    # Строит HTML ссылок пагинации. Используется хелпером +will_paginate+
    # внутренне. Порт link_renderer.rb.
    class LinkRenderer < LinkRendererBase
      @template : I18n?
      @container_attributes : Hash(String, String?)?

      # * +collection+ — WillPaginate::Collection или совместимый объект
      # * +options+ — проброшены из хелпера will_paginate
      # * +template+ — вью-контекст, в котором рендерим (отвечает на
      #   will_paginate_translate)
      def prepare(collection : CollectionMethods, options : Hash(Symbol, OptionValue), template : I18n)
        super(collection, options)
        @template = template
        @container_attributes = nil
      end

      # Погнали! Возвращает полную HTML-строку со ссылками пагинации.
      # Наследуйтесь от LinkRenderer и меняйте этот метод как хотите.
      def to_html : String
        opts = @options.not_nil!
        html = pagination.map do |item|
          item.is_a?(Int32) ? page_number(item) : render_item(item)
        end.join(opts[:link_separator].to_s)

        truthy?(opts[:container]?) ? html_container(html) : html
      end

      # Подмножество options, представляющее HTML-атрибуты контейнера.
      def container_attributes : Hash(String, String?)
        @container_attributes ||= begin
          attributes = {"role" => "navigation",
                        "aria-label" => @template.not_nil!.will_paginate_translate(:container_aria_label) { "Pagination" }} of String => String?
          skip = ViewHelpers.pagination_options.keys + [:renderer]
          skip.delete(:class)
          @options.not_nil!.each do |key, value|
            next if skip.includes?(key)
            attributes[key.to_s] = option_to_s?(value)
          end
          attributes
        end
      end

      protected def page_number(page : Int32) : String
        aria_label = @template.not_nil!.will_paginate_translate(:page_aria_label, {"page" => page}) { "Page #{page}" }
        if page == current_page
          tag(:em, page.to_s,
            {"class" => "current", "aria-label" => aria_label, "aria-current" => "page"} of String => String?)
        else
          link(page.to_s, page, ({"rel" => rel_value(page), "aria-label" => aria_label} of String => String?))
        end
      end

      protected def gap : String
        text = @template.not_nil!.will_paginate_translate(:page_gap) { "&hellip;" }
        %(<span class="gap">#{text}</span>)
      end

      protected def previous_page : String
        cp = current_page
        num = cp > 1 ? cp - 1 : nil
        aria_label = @template.not_nil!.will_paginate_translate(:previous_aria_label) { "Previous page" }
        previous_or_next_page(num, @options.not_nil![:previous_label].to_s, "previous_page", aria_label)
      end

      protected def next_page : String
        num = current_page < total_pages ? current_page + 1 : nil
        aria_label = @template.not_nil!.will_paginate_translate(:next_aria_label) { "Next page" }
        previous_or_next_page(num, @options.not_nil![:next_label].to_s, "next_page", aria_label)
      end

      protected def previous_or_next_page(page : Int32?, text : String, classname : String,
                                          aria_label : String? = nil) : String
        if page
          link(text, page, ({"class" => classname, "aria-label" => aria_label} of String => String?))
        else
          tag(:span, text, ({"class" => "#{classname} disabled", "aria-label" => aria_label} of String => String?))
        end
      end

      protected def html_container(html : String) : String
        tag(:div, html, container_attributes)
      end

      # URL для страницы. Переопределите в подклассе (как Sinatra/ActionView
      # интеграции гема); базовая реализация поднимает NotImplementedError.
      protected def url(page : Int32) : String
        raise NotImplementedError.new
      end

      # protected (не private): подклассы-рендереры зовут это в url,
      # как в геме (Ruby private виден подклассам, Crystal — нет)
      protected def param_name : String
        @options.not_nil![:param_name].to_s
      end

      private def render_item(item : Symbol) : String
        case item
        when :previous_page then previous_page
        when :next_page     then next_page
        when :gap           then gap
        else                     raise ArgumentError.new("unknown pagination item: #{item}")
        end
      end

      private def link(text : String, target : String | Int32,
                       attributes : Hash(String, String?)) : String
        attributes = attributes.dup
        if target.is_a?(Int32)
          attributes["rel"] = rel_value(target)
          target = url(target)
        end
        attributes["href"] = target
        tag(:a, text, attributes)
      end

      private def tag(name : String | Symbol, value : String,
                      attributes : Hash(String, String?)) : String
        string_attributes = attributes.map do |key, attr_value|
          attr_value.nil? ? nil : %( #{key}="#{HTML.escape(attr_value)}")
        end
        "<#{name}#{string_attributes.compact.join}>#{value}</#{name}>"
      end

      private def rel_value(page : Int32) : String?
        if page == current_page - 1
          "prev"
        elsif page == current_page + 1
          "next"
        end
      end

      private def option_to_s?(value : OptionValue) : String?
        value.nil? ? nil : value.to_s
      end
    end
  end
end
