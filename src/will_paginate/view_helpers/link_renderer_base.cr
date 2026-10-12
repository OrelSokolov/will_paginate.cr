module WillPaginate
  module ViewHelpers
    # Основная работа по построению ссылок пагинации. Используется
    # хелпером +will_paginate+ внутренне. Порт link_renderer_base.rb.
    class LinkRendererBase
      alias Item = Int32 | Symbol

      @collection : CollectionMethods?
      @options : Hash(Symbol, OptionValue)?
      @total_pages : Int32?

      # * +collection+ — экземпляр WillPaginate::Collection или любой
      #   объект с тем же API (CollectionMethods)
      # * +options+ — проброшены из хелпера will_paginate
      def prepare(collection : CollectionMethods, options : Hash(Symbol, OptionValue))
        @collection = collection
        @options = options

        # сброс на случай переиспользования экземпляра
        @total_pages = nil
      end

      def pagination : Array(Item)
        opts = @options.not_nil!
        items = truthy?(opts[:page_links]?) ? windowed_page_numbers : [] of Item
        items.unshift(:previous_page)
        items.push(:next_page)
        items
      end

      protected def windowed_page_numbers : Array(Item)
        opts = @options.not_nil!
        inner_window = int_option(opts, :inner_window, 4)
        outer_window = int_option(opts, :outer_window, 1)
        page = current_page
        total = total_pages

        window_from = page - inner_window
        window_to = page + inner_window

        # подгоняем нижнюю/верхнюю границу, если они выходят за пределы
        if window_to > total
          window_from -= window_to - total
          window_to = total
        end
        if window_from < 1
          window_to += 1 - window_from
          window_from = 1
          window_to = total if window_to > total
        end

        # всегда видимы
        middle_from = window_from
        middle_to = window_to

        # левое окно
        left : Array(Item) = if outer_window + 3 < middle_from # есть разрыв
                               left = (1..(outer_window + 1)).map { |i| i.as(Item) }
                               left << :gap
                             else # стыкуется с видимыми страницами
                               (1...middle_from).map { |i| i.as(Item) }
                             end

        # правое окно
        right : Array(Item) = if total - outer_window - 2 > middle_to # снова разрыв
                                right = ((total - outer_window)..total).map { |i| i.as(Item) }
                                right.unshift(:gap)
                              else # стыкуется с видимыми страницами
                                ((middle_to + 1)..total).map { |i| i.as(Item) }
                              end

        left + ((middle_from..middle_to).map { |i| i.as(Item) }) + right
      end

      protected def current_page : Int32
        @collection.not_nil!.current_page.to_i.to_i32
      end

      protected def total_pages : Int32
        @total_pages ||= @collection.not_nil!.total_pages
      end

      protected def truthy?(value : OptionValue) : Bool
        value.is_a?(Bool) ? value : !value.nil?
      end

      private def int_option(opts : Hash(Symbol, OptionValue), key : Symbol, default : Int32) : Int32
        value = opts[key]?
        value.is_a?(Int32) ? value : default
      end
    end
  end
end
