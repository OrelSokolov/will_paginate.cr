require "./collection"

# Порт array.rb: пагинация статического массива (извлечение подмножества).
# Результат — WillPaginate::Collection(T), массив с данными о пагинации.
#
#   arr = ['a', 'b', 'c', 'd', 'e']
#   paged = arr.paginate(per_page: 2)          #->  ['a', 'b']
#   paged.total_entries                        #->  5
#   arr.paginate(page: 2, per_page: 2)         #->  ['c', 'd']
#   arr.paginate(page: 3, per_page: 2)         #->  ['e']
class Array
  def paginate(page : WillPaginate::PageNumber | Int32 | Int64 | String = 1,
               per_page : Int32? = nil, total_entries : Int32? = nil)
    total = total_entries || size
    WillPaginate::Collection(T).create(page, per_page, total) do |pager|
      pager.replace(self[pager.offset, pager.per_page]? || [] of T)
    end
  end
end
