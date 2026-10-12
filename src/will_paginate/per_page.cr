module WillPaginate
  # Порт per_page.rb. Ruby-версия работает через `extend WillPaginate::PerPage`
  # на самом модуле + наследование @per_page в подклассы (Inheritance-хук).
  # В Crystal модуль с ивариантом нельзя `extend` на класс — поэтому PerPage
  # включается через `include` (уровень экземпляра), а глобальный дефолт
  # живёт в `WillPaginate.per_page` / `WillPaginate.per_page=`.
  module PerPage
    @per_page : Int32?

    def per_page : Int32
      @per_page || WillPaginate.per_page
    end

    def per_page=(limit : Int32)
      @per_page = limit
    end
  end

  @@per_page : Int32 = 30

  def self.per_page : Int32
    @@per_page
  end

  def self.per_page=(limit : Int32)
    @@per_page = limit
  end
end
