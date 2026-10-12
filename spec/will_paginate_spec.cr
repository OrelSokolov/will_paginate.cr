# Юнит-тесты для того, что не покрыто oracle-кейсами:
# Deprecation, глобальные pagination_options, кастомный renderer,
# кастомные переводы, PageNumber-арифметика.

require "spec"
require "../src/will_paginate_cr"

class SimpleRenderer < WillPaginate::ViewHelpers::LinkRenderer
  protected def url(page : Int32) : String
    "/items?page=#{page}"
  end
end

class SimpleView
  include WillPaginate::ViewHelpers
end

# PerPage в Crystal — include-модуль (extend модуля с ивариантом невозможен)
class PerPageModel
  include WillPaginate::PerPage

  property value : Int32 = 0
end

describe "WillPaginate unit" do
  view = SimpleView.new

  describe "PageNumber" do
    it "арифметика возвращает Integer, как делегаты в Ruby" do
      pn = WillPaginate.page_number(3)
      (pn - 1).should eq 2
      (pn + 2).should eq 5
      (pn * 2).should eq 6
      (pn / 2).should eq 1
    end

    it "идемпотентная коэрция" do
      pn = WillPaginate.page_number(2)
      WillPaginate.page_number(pn).should eq pn
    end

    it "offset ограничен BIGINT" do
      expect_raises(WillPaginate::InvalidPage, "invalid offset: \"9223372036854775808\"") do
        WillPaginate::PageNumber.new("9223372036854775808", "offset")
      end
    end
  end

  describe "PerPage" do
    it "включается через include с собственным лимитом" do
      model = PerPageModel.new
      model.per_page.should eq 30
      model.per_page = 7
      model.per_page.should eq 7
      WillPaginate.per_page.should eq 30
    end
  end

  describe "Deprecation" do
    it "deprecate_key печатает warning при записи" do
      h = WillPaginate::Deprecation::Hash(Symbol, String).new
      h.deprecate_key(:old, message: "use :new instead")
      h[:fine] = "ok"
      h[:old] = "x"
      h[:old].should eq "x"
    end

    it "pagination_options[:renderer] помечен устаревшим" do
      # тип значения — OptionValue, а сообщение — через блок
      WillPaginate::ViewHelpers.pagination_options.deprecate_key(:renderer) { |key, _|
        "pagination_options[#{key.inspect}] shouldn't be set globally"
      }
    end
  end

  describe "глобальные pagination_options" do
    it "переопределяют дефолты" do
      coll = (1..60).to_a.paginate(page: 2, per_page: 10)
      WillPaginate::ViewHelpers.pagination_options[:page_links] = false
      begin
        html = view.will_paginate(coll, SimpleRenderer)
        html.should_not be_nil
        html.not_nil!.scan(/href/).size.should eq 2 # только prev и next
      ensure
        WillPaginate::ViewHelpers.pagination_options[:page_links] = true
      end
    end
  end

  describe "кастомные переводы" do
    it "лейблы берутся из локали" do
      WillPaginate::I18n.store_translations("ru",
        {"previous_label" => "← Назад"} of String => String)
      WillPaginate::I18n.locale = "ru"
      begin
        coll = (1..30).to_a.paginate(per_page: 10)
        html = view.will_paginate(coll, SimpleRenderer).not_nil!
        html.should contain("← Назад")
      ensure
        WillPaginate::I18n.locale = "en"
      end
    end
  end

  describe "кастомная коллекция" do
    it "включает CollectionMethods" do
      custom = WillPaginate::Collection(String).create(2, 5, 21) { |p| p.replace(["a", "b", "c", "d", "e"]) }
      view.will_paginate(custom, SimpleRenderer).not_nil!.should contain(%(href="/items?page=1"))
      view.page_entries_info(custom, model: "entry").should eq(
        "Displaying entries <b>6&nbsp;-&nbsp;10</b> of <b>21</b> in total")
    end
  end
end
