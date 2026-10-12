# Oracle cases: запуск against настоящего will_paginate 4.0.1 (plain Ruby,
# без Rails/ActiveSupport). Печатает строки "id\tvalue" (с \n\t\r эскейпами).
#
#   ruby oracle/cases.rb > oracle/expected.yml
#
# Секция page_entries_info подгружает настоящий гем i18n + models-переводы,
# чтобы снять рабочий (не fallback) путь перевода.

require 'will_paginate/collection'
require 'will_paginate/array'
require 'will_paginate/view_helpers/link_renderer'

def esc(s)
  s.to_s.gsub("\\", "\\\\\\\\").gsub("\t", "\\t").gsub("\n", "\\n").gsub("\r", "\\r")
end

def case_out(id, value)
  puts "#{id}\t#{esc(value)}"
end

# --- Тестовый рендерер: url как у Sinatra-адаптера, только с param_name ------

class TestRenderer < WillPaginate::ViewHelpers::LinkRenderer
  protected

  def url(page)
    "/foo?#{param_name}=#{page}"
  end
end

class TestView
  include WillPaginate::ViewHelpers

  def wp(collection, options = {})
    will_paginate(collection, { :renderer => TestRenderer }.merge(options))
  end
end

view = TestView.new

# --- PageNumber / InvalidPage ------------------------------------------------

case_out('pn_inspect', WillPaginate::PageNumber(3).inspect)               # page 3
case_out('pn_to_i', WillPaginate::PageNumber(3).to_i)                     # 3
case_out('pn_eq', WillPaginate::PageNumber(3) == 3)                       # true
case_out('pn_cmp', (WillPaginate::PageNumber(2) <=> 3))                   # -1
case_out('pn_to_s', WillPaginate::PageNumber(3).to_s)                     # 3
case_out('pn_offset', WillPaginate::PageNumber(3).to_offset(10).inspect)  # offset 20
case_out('pn_offset_to_i', WillPaginate::PageNumber(3).to_offset(10).to_i)
case_out('pn_string_coerce', WillPaginate::PageNumber('3').inspect)

begin
  WillPaginate::PageNumber(0)
rescue => e
  case_out('pn_invalid_zero', "range_error=#{e.is_a?(RangeError)}: #{e.message} invalid_page=#{e.is_a?(WillPaginate::InvalidPage)}")
end

begin
  WillPaginate::PageNumber.new(-5, 'offset')
rescue => e
  case_out('pn_invalid_offset', "range_error=#{e.is_a?(RangeError)}: #{e.message} invalid_page=#{e.is_a?(WillPaginate::InvalidPage)}")
end

begin
  WillPaginate::PageNumber('abc')
rescue => e
  case_out('pn_invalid_string', "invalid_page=#{e.is_a?(WillPaginate::InvalidPage)}")
end

begin
  WillPaginate::PageNumber(nil)
rescue => e
  case_out('pn_invalid_nil', "invalid_page=#{e.is_a?(WillPaginate::InvalidPage)}")
end

# --- PerPage -------------------------------------------------------------------

case_out('per_page_default', WillPaginate.per_page)
WillPaginate.per_page = 7
case_out('per_page_set', WillPaginate.per_page)
case_out('per_page_used', WillPaginate::Collection.new(3).per_page)
WillPaginate.per_page = 30

# --- Collection ------------------------------------------------------------------

def coll_info(c)
  "#{c.current_page}/#{c.per_page}/#{c.total_entries.inspect}/#{c.total_pages}/#{c.offset}/" \
    "#{c.previous_page.inspect}/#{c.next_page.inspect}/#{c.out_of_bounds?}"
end

case_out('coll_basic', coll_info(WillPaginate::Collection.new(1, 10, 26)))
case_out('coll_oob', coll_info(WillPaginate::Collection.new(5, 10, 26)))
case_out('coll_empty', coll_info(WillPaginate::Collection.new(1, 10, 0)))
case_out('coll_replace', WillPaginate::Collection.create(1, 10, 26) { |p| p.replace((1..10).to_a) }.to_s)

pager = WillPaginate::Collection.create(1, 10) { |p| p.replace([1, 2, 3]) }
case_out('coll_guess_short', "#{pager.total_entries.inspect}/#{pager.length}")
pager = WillPaginate::Collection.create(2, 10) { |p| p.replace((1..5).to_a) }
case_out('coll_guess_page2', "#{pager.total_entries.inspect}/#{pager.length}/#{pager.out_of_bounds?}")
pager = WillPaginate::Collection.create(2, 10) { |p| p.replace([]) }
case_out('coll_guess_nil', "#{pager.total_entries.inspect}/#{pager.length}")
pager = WillPaginate::Collection.create(2, 10) { |p| p.replace((1..10).to_a) }
case_out('coll_guess_full_page', "#{pager.total_entries.inspect}/#{pager.length}")
pager = WillPaginate::Collection.create(1, 10) { |p| p.replace((1..10).to_a) }
case_out('coll_guess_page1_full', "#{pager.total_entries.inspect}/#{pager.length}")

# --- Array#paginate ----------------------------------------------------------------

paged = (1..5).to_a.paginate(per_page: 2)
case_out('arr_paginate_1', "#{paged.to_a}/#{paged.total_entries}/#{paged.total_pages}/#{paged.current_page}")
paged = (1..5).to_a.paginate(page: 2, per_page: 2)
case_out('arr_paginate_2', "#{paged.to_a}/#{paged.previous_page.inspect}/#{paged.next_page.inspect}")
paged = (1..5).to_a.paginate(page: 3, per_page: 2)
case_out('arr_paginate_3', "#{paged.to_a}/#{paged.previous_page.inspect}/#{paged.next_page.inspect}")
paged = (1..5).to_a.paginate(page: 1, per_page: 2, total_entries: 99)
case_out('arr_paginate_total', "#{paged.to_a}/#{paged.total_entries}/#{paged.total_pages}/#{paged.out_of_bounds?}")
paged = (1..5).to_a.paginate(page: 99, per_page: 2)
case_out('arr_paginate_oob', "#{paged.to_a}/#{paged.out_of_bounds?}/#{paged.offset}")
paged = %w[a b c d e].paginate(per_page: 2)
case_out('arr_paginate_strings', paged.to_a)

# --- will_paginate (без i18n: fallback-лейблы) -------------------------------------

basic  = (1..26).to_a.paginate(page: 1, per_page: 10)
page2  = (1..26).to_a.paginate(page: 2, per_page: 10)
gaps   = (1..300).to_a.paginate(page: 15, per_page: 10)
first  = (1..300).to_a.paginate(page: 1, per_page: 10)
last   = (1..300).to_a.paginate(page: 30, per_page: 10)
second = (1..300).to_a.paginate(page: 2, per_page: 10)
window = (1..100).to_a.paginate(page: 5, per_page: 10)

case_out('wp_basic', view.wp(basic))
case_out('wp_page2', view.wp(page2))
case_out('wp_gaps', view.wp(gaps))
case_out('wp_first', view.wp(first))
case_out('wp_last', view.wp(last))
case_out('wp_second', view.wp(second))
case_out('wp_window_shift', view.wp(window))
case_out('wp_labels', view.wp(page2, previous_label: '&laquo;', next_label: '&raquo;'))
case_out('wp_page_links_false', view.wp(gaps, page_links: false))
case_out('wp_container_false', view.wp(basic, container: false))
case_out('wp_class', view.wp(basic, class: 'pagi'))
case_out('wp_attrs', view.wp(basic, id: 'abc', style: 'color:blue'))
case_out('wp_separator', view.wp(basic, link_separator: ' | '))
case_out('wp_windows', view.wp(window, inner_window: 1, outer_window: 0))
case_out('wp_param_name', view.wp(basic, param_name: 'p'))
case_out('wp_single_page', view.wp((1..5).to_a.paginate(per_page: 10)).inspect)
case_out('wp_renderer_instance', view.wp(basic, renderer: TestRenderer.new))
case_out('wp_aria_current', view.wp(page2).include?('aria-current'))

begin
  view.wp(basic, renderer: nil)
rescue ArgumentError => e
  case_out('wp_no_renderer', "#{e.class}: #{e.message}")
end

# --- page_entries_info: standalone (без i18n) — pluralize нет ----------------------

empty1 = WillPaginate::Collection.new(1, 10, 0)
begin
  view.page_entries_info(empty1)
rescue => e
  case_out('pei_raise_no_pluralize', "jump_error=#{e.is_a?(LocalJumpError)}: #{e.message}")
end

# --- page_entries_info: с настоящим i18n + models-переводами -----------------------

require 'i18n'
I18n.load_path += WillPaginate::I18n.load_path
I18n.enforce_available_locales = false
I18n.locale = :en
I18n.backend.store_translations :en, will_paginate: {
  models: {
    entry: { zero: 'entries', one: 'entry', other: 'entries' },
    post:  { zero: 'posts', one: 'post', other: 'posts' },
  },
}

one    = WillPaginate::Collection.create(1, 10, 1)  { |p| p.replace([1]) }
all26  = WillPaginate::Collection.create(1, 10, 26) { |p| p.replace((1..10).to_a) }
multi  = WillPaginate::Collection.create(2, 10, 26) { |p| p.replace((11..20).to_a) }
allfit = WillPaginate::Collection.create(1, 30, 26) { |p| p.replace((1..26).to_a) }

case_out('pei_zero_html', view.page_entries_info(empty1))
case_out('pei_zero_text', view.page_entries_info(empty1, html: false))
case_out('pei_one_html', view.page_entries_info(one, model: 'entry'))
case_out('pei_one_text', view.page_entries_info(one, model: 'entry', html: false))
case_out('pei_all_html', view.page_entries_info(all26, model: 'entry'))
case_out('pei_all_text', view.page_entries_info(all26, model: 'entry', html: false))
case_out('pei_multi_html', view.page_entries_info(multi, model: 'entry'))
case_out('pei_multi_text', view.page_entries_info(multi, model: 'entry', html: false))
case_out('pei_model', view.page_entries_info(multi, model: 'post'))
case_out('pei_model_text', view.page_entries_info(multi, model: 'post', html: false))
case_out('pei_all_fit_html', view.page_entries_info(allfit, model: 'entry'))
case_out('pei_all_fit_text', view.page_entries_info(allfit, model: 'entry', html: false))
