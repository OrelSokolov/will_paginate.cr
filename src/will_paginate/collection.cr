require "./per_page"
require "./page_number"

module WillPaginate
  # Любая will_paginate-совместимая коллекция должна уметь:
  #
  #   current_page, per_page, offset, total_entries, total_pages, size
  #
  # опционально:
  #
  #   out_of_bounds?, previous_page, next_page
  #
  # Этот модуль реализует часть из них (порт CollectionMethods).
  module CollectionMethods
    abstract def current_page : PageNumber
    abstract def per_page : Int32
    abstract def total_entries : Int32?
    abstract def size : Int32

    def total_pages : Int32
      entries = total_entries.not_nil!
      entries.zero? ? 1 : (entries + per_page - 1) // per_page
    end

    # current_page - 1 или nil, если предыдущей страницы нет
    def previous_page : Int64?
      page = current_page.to_i
      page > 1 ? page - 1 : nil
    end

    # current_page + 1 или nil, если следующей страницы нет
    def next_page : Int64?
      page = current_page.to_i
      page < total_pages ? page + 1 : nil
    end

    # true, когда запрошена страница с номером больше последней.
    def out_of_bounds? : Bool
      current_page.to_i > total_pages
    end

    def offset : Int64
      current_page.to_offset(per_page).to_i
    end
  end

  # = Ключ к пагинации
  #
  # WillPaginate::Collection — обычный массив с дополнительными свойствами
  # (current_page, per_page, total_entries), используемыми вью-хелперами.
  # См. также `create`.
  class Collection(T) < Array(T)
    include CollectionMethods

    getter current_page : PageNumber
    getter per_page : Int32
    getter total_entries : Int32?

    def initialize(page : PageNumber | Int32 | Int64 | String | Nil,
                   per_page : Int32? = nil, total : Int32? = nil)
      super()
      @current_page = WillPaginate.page_number(page)
      @per_page = per_page || WillPaginate.per_page
      @total_entries = total
    end

    # Как `new`, но передаёт объект в блок и возвращает его после —
    # удобно для ручной пагинации:
    #
    #   entries = WillPaginate::Collection(Int32).create(1, 10) do |pager|
    #     result = fetch(limit: pager.per_page, offset: pager.offset)
    #     pager.replace(result)
    #     pager.total_entries = count_all unless pager.total_entries
    #   end
    def self.create(page : PageNumber | Int32 | Int64 | String | Nil,
                    per_page : Int32? = nil, total : Int32? = nil, &block : self -> _)
      pager = new(page, per_page, total)
      yield pager
      pager
    end

    def total_entries=(number : Int32)
      @total_entries = number
    end

    # Ruby-совместимый алиас Array#length (в Crystal — size)
    def length : Int32
      size
    end

    # Магическая обёртка над Array#replace: если переданный массив короче
    # лимита per_page, мы знаем, что находимся на последней странице, и
    # total_entries вычисляется сам (offset + length).
    def replace(other : Array(T)) : self
      super(other)
      if @total_entries.nil? && size < @per_page && (@current_page.to_i == 1 || size > 0)
        @total_entries = (offset + size).to_i32
      end
      self
    end
  end
end
