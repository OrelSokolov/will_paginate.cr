# Oracle spec: порт обязан воспроизвести oracle/expected.yml (снятом с
# настоящего will_paginate 4.0.1 через oracle/cases.rb) — 1:1 те же case id.
# Значения — escape-протокол \n/\t/\r, как в остальных шардах.

require "spec"
require "../src/will_paginate_cr"

EXPECTED = begin
  hash = {} of String => String
  File.read("#{__DIR__}/../oracle/expected.yml").each_line do |line|
    if line.includes?('\t')
      id, value = line.split('\t', 2)
      hash[id] = value.chomp
    end
  end
  hash
end

def check(id, value)
  (EXPECTED[id]? || "MISSING #{id}").should eq value.to_s
end

# --- Тестовый рендерер (аналог TestRenderer в oracle/cases.rb) ---------------

class TestRenderer < WillPaginate::ViewHelpers::LinkRenderer
  protected def url(page : Int32) : String
    "/foo?#{param_name}=#{page}"
  end
end

class TestView
  include WillPaginate::ViewHelpers

  def wp(collection, renderer = TestRenderer, **options)
    will_paginate(collection, renderer, **options)
  end
end

view = TestView.new

def coll_info(c)
  "#{c.current_page}/#{c.per_page}/#{c.total_entries.inspect}/#{c.total_pages}/#{c.offset}/" \
    "#{c.previous_page.inspect}/#{c.next_page.inspect}/#{c.out_of_bounds?}"
end

describe "WillPaginate oracle" do
  # --- PageNumber / InvalidPage ----------------------------------------------

  it "pn_inspect" do
    check "pn_inspect", WillPaginate.page_number(3).inspect
  end

  it "pn_to_i" do
    check "pn_to_i", WillPaginate.page_number(3).to_i
  end

  it "pn_eq" do
    check "pn_eq", WillPaginate.page_number(3) == 3
  end

  it "pn_cmp" do
    check "pn_cmp", (WillPaginate.page_number(2) <=> 3)
  end

  it "pn_to_s" do
    check "pn_to_s", WillPaginate.page_number(3).to_s
  end

  it "pn_offset" do
    check "pn_offset", WillPaginate.page_number(3).to_offset(10).inspect
  end

  it "pn_offset_to_i" do
    check "pn_offset_to_i", WillPaginate.page_number(3).to_offset(10).to_i
  end

  it "pn_string_coerce" do
    check "pn_string_coerce", WillPaginate.page_number("3").inspect
  end

  it "pn_invalid_zero" do
    e = expect_raises(WillPaginate::InvalidPage) { WillPaginate.page_number(0) }
    check "pn_invalid_zero", "range_error=#{e.is_a?(ArgumentError)}: #{e.message} invalid_page=#{e.is_a?(WillPaginate::InvalidPage)}"
  end

  it "pn_invalid_offset" do
    e = expect_raises(WillPaginate::InvalidPage) { WillPaginate::PageNumber.new(-5, "offset") }
    check "pn_invalid_offset", "range_error=#{e.is_a?(ArgumentError)}: #{e.message} invalid_page=#{e.is_a?(WillPaginate::InvalidPage)}"
  end

  it "pn_invalid_string" do
    e = expect_raises(WillPaginate::InvalidPage) { WillPaginate.page_number("abc") }
    check "pn_invalid_string", "invalid_page=#{e.is_a?(WillPaginate::InvalidPage)}"
  end

  it "pn_invalid_nil" do
    e = expect_raises(WillPaginate::InvalidPage) { WillPaginate.page_number(nil) }
    check "pn_invalid_nil", "invalid_page=#{e.is_a?(WillPaginate::InvalidPage)}"
  end

  # --- PerPage -----------------------------------------------------------------

  it "per_page_default" do
    check "per_page_default", WillPaginate.per_page
  end

  it "per_page_set" do
    WillPaginate.per_page = 7
    begin
      check "per_page_set", WillPaginate.per_page
      check "per_page_used", WillPaginate::Collection(Int32).new(3).per_page
    ensure
      WillPaginate.per_page = 30
    end
  end

  # --- Collection ----------------------------------------------------------------

  it "coll_basic" do
    check "coll_basic", coll_info(WillPaginate::Collection(Int32).new(1, 10, 26))
  end

  it "coll_oob" do
    check "coll_oob", coll_info(WillPaginate::Collection(Int32).new(5, 10, 26))
  end

  it "coll_empty" do
    check "coll_empty", coll_info(WillPaginate::Collection(Int32).new(1, 10, 0))
  end

  it "coll_replace" do
    pager = WillPaginate::Collection(Int32).create(1, 10, 26) { |p| p.replace((1..10).to_a) }
    check "coll_replace", pager.to_a
  end

  it "coll_guess_short" do
    pager = WillPaginate::Collection(Int32).create(1, 10) { |p| p.replace([1, 2, 3]) }
    check "coll_guess_short", "#{pager.total_entries.inspect}/#{pager.length}"
  end

  it "coll_guess_page2" do
    pager = WillPaginate::Collection(Int32).create(2, 10) { |p| p.replace((1..5).to_a) }
    check "coll_guess_page2", "#{pager.total_entries.inspect}/#{pager.length}/#{pager.out_of_bounds?}"
  end

  it "coll_guess_nil" do
    pager = WillPaginate::Collection(Int32).create(2, 10) { |p| p.replace([] of Int32) }
    check "coll_guess_nil", "#{pager.total_entries.inspect}/#{pager.length}"
  end

  it "coll_guess_full_page" do
    pager = WillPaginate::Collection(Int32).create(2, 10) { |p| p.replace((1..10).to_a) }
    check "coll_guess_full_page", "#{pager.total_entries.inspect}/#{pager.length}"
  end

  it "coll_guess_page1_full" do
    pager = WillPaginate::Collection(Int32).create(1, 10) { |p| p.replace((1..10).to_a) }
    check "coll_guess_page1_full", "#{pager.total_entries.inspect}/#{pager.length}"
  end

  # --- Array#paginate ---------------------------------------------------------------

  it "arr_paginate_1" do
    paged = (1..5).to_a.paginate(per_page: 2)
    check "arr_paginate_1", "#{paged.to_a}/#{paged.total_entries}/#{paged.total_pages}/#{paged.current_page}"
  end

  it "arr_paginate_2" do
    paged = (1..5).to_a.paginate(page: 2, per_page: 2)
    check "arr_paginate_2", "#{paged.to_a}/#{paged.previous_page.inspect}/#{paged.next_page.inspect}"
  end

  it "arr_paginate_3" do
    paged = (1..5).to_a.paginate(page: 3, per_page: 2)
    check "arr_paginate_3", "#{paged.to_a}/#{paged.previous_page.inspect}/#{paged.next_page.inspect}"
  end

  it "arr_paginate_total" do
    paged = (1..5).to_a.paginate(page: 1, per_page: 2, total_entries: 99)
    check "arr_paginate_total", "#{paged.to_a}/#{paged.total_entries}/#{paged.total_pages}/#{paged.out_of_bounds?}"
  end

  it "arr_paginate_oob" do
    paged = (1..5).to_a.paginate(page: 99, per_page: 2)
    check "arr_paginate_oob", "#{paged.to_a}/#{paged.out_of_bounds?}/#{paged.offset}"
  end

  it "arr_paginate_strings" do
    paged = %w[a b c d e].paginate(per_page: 2)
    check "arr_paginate_strings", paged.to_a
  end

  # --- will_paginate ------------------------------------------------------------------

  basic  = (1..26).to_a.paginate(page: 1, per_page: 10)
  page2  = (1..26).to_a.paginate(page: 2, per_page: 10)
  gaps   = (1..300).to_a.paginate(page: 15, per_page: 10)
  first  = (1..300).to_a.paginate(page: 1, per_page: 10)
  last   = (1..300).to_a.paginate(page: 30, per_page: 10)
  second = (1..300).to_a.paginate(page: 2, per_page: 10)
  window = (1..100).to_a.paginate(page: 5, per_page: 10)

  it "wp_basic" do
    check "wp_basic", view.wp(basic)
  end

  it "wp_page2" do
    check "wp_page2", view.wp(page2)
  end

  it "wp_gaps" do
    check "wp_gaps", view.wp(gaps)
  end

  it "wp_first" do
    check "wp_first", view.wp(first)
  end

  it "wp_last" do
    check "wp_last", view.wp(last)
  end

  it "wp_second" do
    check "wp_second", view.wp(second)
  end

  it "wp_window_shift" do
    check "wp_window_shift", view.wp(window)
  end

  it "wp_labels" do
    check "wp_labels", view.wp(page2, previous_label: "&laquo;", next_label: "&raquo;")
  end

  it "wp_page_links_false" do
    check "wp_page_links_false", view.wp(gaps, page_links: false)
  end

  it "wp_container_false" do
    check "wp_container_false", view.wp(basic, container: false)
  end

  it "wp_class" do
    check "wp_class", view.wp(basic, class: "pagi")
  end

  it "wp_attrs" do
    check "wp_attrs", view.wp(basic, id: "abc", style: "color:blue")
  end

  it "wp_separator" do
    check "wp_separator", view.wp(basic, link_separator: " | ")
  end

  it "wp_windows" do
    check "wp_windows", view.wp(window, inner_window: 1, outer_window: 0)
  end

  it "wp_param_name" do
    check "wp_param_name", view.wp(basic, param_name: "p")
  end

  it "wp_single_page" do
    check "wp_single_page", view.wp((1..5).to_a.paginate(per_page: 10)).inspect
  end

  it "wp_renderer_instance" do
    check "wp_renderer_instance", view.wp(basic, TestRenderer.new)
  end

  it "wp_aria_current" do
    check "wp_aria_current", view.wp(page2).try(&.includes?("aria-current"))
  end

  it "wp_no_renderer" do
    e = expect_raises(ArgumentError) { view.wp(basic, nil) }
    check "wp_no_renderer", "#{e.class.name}: #{e.message}"
  end

  # --- page_entries_info --------------------------------------------------------------

  empty1 = WillPaginate::Collection(Int32).new(1, 10, 0)

  it "pei_raise_no_pluralize" do
    e = expect_raises(WillPaginate::LocalJumpError) { view.page_entries_info(empty1) }
    check "pei_raise_no_pluralize", "jump_error=#{e.is_a?(WillPaginate::LocalJumpError)}: #{e.message}"
  end

  # models-переводы (аналог I18n.backend.store_translations в cases.rb;
  # внутри it — чтобы выполнялись ПОСЛЕ pei_raise_no_pluralize, как в скрипте)
  it "register models translations" do
    WillPaginate::I18n.store_translations("en",
      {"models" => {"entry" => {"zero" => "entries", "one" => "entry", "other" => "entries"},
                    "post"  => {"zero" => "posts", "one" => "post", "other" => "posts"}}} of String => Hash(String, Hash(String, String)))
  end

  one    = WillPaginate::Collection(Int32).create(1, 10, 1) { |p| p.replace([1]) }
  all26  = WillPaginate::Collection(Int32).create(1, 10, 26) { |p| p.replace((1..10).to_a) }
  multi  = WillPaginate::Collection(Int32).create(2, 10, 26) { |p| p.replace((11..20).to_a) }
  allfit = WillPaginate::Collection(Int32).create(1, 30, 26) { |p| p.replace((1..26).to_a) }

  it "pei_zero_html" do
    check "pei_zero_html", view.page_entries_info(empty1)
  end

  it "pei_zero_text" do
    check "pei_zero_text", view.page_entries_info(empty1, html: false)
  end

  it "pei_one_html" do
    check "pei_one_html", view.page_entries_info(one, model: "entry")
  end

  it "pei_one_text" do
    check "pei_one_text", view.page_entries_info(one, model: "entry", html: false)
  end

  it "pei_all_html" do
    check "pei_all_html", view.page_entries_info(all26, model: "entry")
  end

  it "pei_all_text" do
    check "pei_all_text", view.page_entries_info(all26, model: "entry", html: false)
  end

  it "pei_multi_html" do
    check "pei_multi_html", view.page_entries_info(multi, model: "entry")
  end

  it "pei_multi_text" do
    check "pei_multi_text", view.page_entries_info(multi, model: "entry", html: false)
  end

  it "pei_model" do
    check "pei_model", view.page_entries_info(multi, model: "post")
  end

  it "pei_model_text" do
    check "pei_model_text", view.page_entries_info(multi, model: "post", html: false)
  end

  it "pei_all_fit_html" do
    check "pei_all_fit_html", view.page_entries_info(allfit, model: "entry")
  end

  it "pei_all_fit_text" do
    check "pei_all_fit_text", view.page_entries_info(allfit, model: "entry", html: false)
  end
end
