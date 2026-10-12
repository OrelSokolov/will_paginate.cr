module WillPaginate
  # Ruby-оригинал расширяет RangeError/TypeError модулем InvalidPage
  # (`error.extend InvalidPage`). В Crystal — одиночное наследование,
  # поэтому InvalidPage — сам класс ошибок (ловится и как ArgumentError).
  class InvalidPage < ArgumentError
  end

  # Аналог ::LocalJumpError из ядра Ruby: его поднимает page_entries_info,
  # когда перевод недоступен, а блок-fallback не передан.
  class LocalJumpError < Exception
  end

  # Целое, представляющее номер страницы. Порт page_number.rb.
  struct PageNumber
    # значение больше этого не поддерживается в SQL-запросах
    BIGINT = 9223372036854775807_i64

    getter name : String

    @value : Int64

    def initialize(value : Int32 | Int64 | String | Nil, name : String = "page")
      v = case value
          when Int32 then value.to_i64
          when Int64 then value
          when String
            value.to_i64?
          else
            nil
          end
      if v.nil?
        raise InvalidPage.new("invalid #{name}: #{value.inspect}")
      end
      if name == "offset" ? (v < 0 || v > BIGINT) : v < 1
        raise InvalidPage.new("invalid #{name}: #{value.inspect}")
      end
      @name = name
      @value = v
    end

    def to_i : Int64
      @value
    end

    def to_s(io : IO) : Nil
      io << @value
    end

    def inspect(io : IO) : Nil
      io << @name << ' ' << @value
    end

    def ==(other : PageNumber) : Bool
      @value == other.@value
    end

    def ==(other : Int) : Bool
      @value == other
    end

    def <=>(other : PageNumber) : Int32
      @value <=> other.@value
    end

    def <=>(other : Int) : Int32
      @value <=> other
    end

    def <(other : Int) : Bool
      @value < other
    end

    def >(other : Int) : Bool
      @value > other
    end

    def +(other : Int) : Int64
      @value + other
    end

    def -(other : Int) : Int64
      @value - other
    end

    def *(other : Int) : Int64
      @value * other
    end

    def /(other : Int) : Int64
      @value // other
    end

    def to_offset(per_page : Int) : PageNumber
      PageNumber.new((@value - 1) * per_page, "offset")
    end
  end

  # Идемпотентная коэрция. В Ruby это `WillPaginate.PageNumber(value, name)`
  # (метод с большой буквы — в Crystal такой синтаксис невозможен).
  def self.page_number(value : PageNumber | Int32 | Int64 | String | Nil, name : String = "page") : PageNumber
    value.is_a?(PageNumber) ? value : PageNumber.new(value, name)
  end
end
