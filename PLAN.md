# will_paginate.cr — порт will_paginate

> ⚠️ EXPERIMENTAL, DO NOT USE IN PRODUCTION YET.

Порт [mislav/will_paginate](https://github.com/mislav/will_paginate) **4.0.1** на Crystal.
Оригинал: `~/.rvm/gems/ruby-3.4.5/gems/will_paginate-4.0.1`.

## Статус

**Готово, зелёное**: 102 примера (`crystal spec`):
- `spec/oracle_spec.cr` — 62 кейса, снятых с настоящего гема
  (`oracle/cases.rb > oracle/expected.yml`, plain Ruby без Rails/i18n для
  вью-хелперов + настоящий гем i18n для page_entries_info), воспроизводятся 1:1;
- `spec/will_paginate_spec.cr` — юнит-тесты непокрытого: Deprecation::Hash,
  глобальные `pagination_options`, кастомный renderer, кастомные переводы,
  PageNumber-арифметика, включение CollectionMethods;
- `spec/action_view_spec.cr` — интеграция с action_view.cr (crails, см. ниже):
  ERB-шаблоны компилируются template_processor'ом crails, вывод пагинации
  байт-в-байт с oracle-кейсом wp_gaps;
- `spec/active_record_spec.cr` — интеграция с active_record.cr (crails,
  см. ниже): `paginate`/`page` на классе модели / Relation /
  CollectionProxy (ассоциации), отдельная БД `crails_wp_test`.

Портировано фреймворк-независимое ядро гема (lib/will_paginate/{per_page,
page_number, collection, array, deprecation, i18n, view_helpers, view_helpers/
link_renderer{,_base}} + locale/en.yml) и интеграции active_record.rb
(`src/will_paginate/active_record.cr`) и view_helpers/action_view.rb
(`src/will_paginate/view_helpers/action_view.cr`) — обе опциональные,
не подключаются главным require'ом. Mongoid/Sequel/Sinatra/Hanami-интеграции
гема не портились — их роль в Crystal играют подклассы `LinkRenderer`
с собственным `url(page)`.

## API 1:1

- `WillPaginate.per_page` / `WillPaginate.per_page =` (дефолт 30)
- `WillPaginate.page_number(value, name = "page")` (Ruby: `WillPaginate.PageNumber()`)
- `WillPaginate::PageNumber` (inspect `"page 3"` / `"offset 20"`, `to_offset`,
  `==`, `<=>`, арифметика), `WillPaginate::InvalidPage < ArgumentError`
  ("invalid page: 0"), `WillPaginate::LocalJumpError`
- `WillPaginate::Collection(T) < Array(T)` (+ `CollectionMethods`):
  `current_page/per_page/total_entries/offset/total_pages/previous_page/
  next_page/out_of_bounds?`, `create(page, per_page, total) { |pager| ... }`,
  магический `replace` с догадкой о total_entries
- `Array#paginate(page:, per_page:, total_entries:)`
- `WillPaginate::ViewHelpers`:
  - `pagination_options` (Deprecation::Hash, глобальные дефолты;
    `:previous_label`/`:next_label`/`:renderer` помечены устаревшими)
  - `will_paginate(collection, renderer, **options)` — nil при ≤1 странице;
    опции `class/previous_label/next_label/inner_window/outer_window/
    link_separator/param_name/page_links/container`, лишние опции →
    HTML-атрибуты контейнера
  - `page_entries_info(collection, model:, html:)`
- `WillPaginate::ViewHelpers::LinkRendererBase` (`windowed_page_numbers`,
  `pagination`) и `LinkRenderer` (`to_html`, `container_attributes`,
  `page_number`/`gap`/`previous_page`/`next_page`/`html_container`/`tag`,
  `url` → NotImplementedError, protected `param_name`)
- `WillPaginate::I18n` — мини-бэкенд: scope `will_paginate`, defaults-цепочка,
  count-плорализация zero/one/other, интерполяция `%{name}`, en-локаль из гема
  (`store_translations` для models.<key>/других локалей)
- `WillPaginate::Deprecation.warn`, `Deprecation::Hash(K,V)#deprecate_key`

## Отличия от Ruby (статическая типизация)

- `renderer` — позиционный аргумент `will_paginate`, а не ключ хэша опций:
  в типизированном `Hash(Symbol, OptionValue)` нельзя хранить классы.
- `page_entries_info` берёт `model` только из опции (default `"entry"`):
  `collection.first.class` недоступен через интерфейс `CollectionMethods`.
- `WillPaginate::InvalidPage` — класс (Ruby расширяет им RangeError/TypeError;
  ловится и как `ArgumentError`). Отсутствие перевода без блока поднимает
  `WillPaginate::LocalJumpError` ("no block given (yield)") — как standalone-
  поведение гема.
- `OptionValue = Nil|Bool|Int32|String|Symbol|Hash(Symbol,String)` —
  типизированные опции; `params : Hash(Symbol, String)`.
- `PerPage` — include-модуль (extend модуля с ивариантом в Crystal невозможен);
  глобальный дефолт — `WillPaginate.per_page`. Inheritance-хук не портирован.
- `core_ext` (String#underscore, Hash#except) — функции `WillPaginate.underscore`
  и внутренний except, без монкипатча ядра.
- vars переводов — строковые ключи (`String#to_sym` в Crystal нет).

## Обход багов/ограничений Crystal 1.21

1. `Hash#values` с рекурсивным алиасом `Node` не компилируется — первый
   элемент достаётся итерацией в `select_plural`.
2. Рекурсивный алиас в аннотации возвращаемого типа (`: Node?`) не
   унифицируется — аннотация убрана с `select_plural`.
3. `block_given?` нет — две перегрузки `translate`/`will_paginate_translate`
  (с блоком и без).
4. `String#gsub` с Regex-блоком даёт String, не MatchData — `underscore`
  через строковые замены с обратными ссылками (`"\\1_\\2"`, как в гемe).

## Интеграция с action_view.cr (crails, ~/rails.cr)

Порт `view_helpers/action_view.rb` гема — опциональный файл
`src/will_paginate/view_helpers/action_view.cr` (не подключается главным
require'ом; в `development_dependencies` — action_view_cr по path). API в
ERB сохранён как в оракуле:

```crystal
# application_controller.cr
require "will_paginate_cr"
require "will_paginate/view_helpers/action_view"

abstract class ApplicationController < ActionController::Base
  include WillPaginate::ActionView
end
```

```erb
<%= will_paginate @posts %>                      <%# рендерер по умолчанию, как в Rails %>
<%= page_entries_info @posts, model: "post" %>
<%= paginated_section @posts do %> ... <% end %>
```

- `WillPaginate::ActionView::LinkRenderer` — URL = `request.path` +
  GET-параметры запроса (page заменяется на месте, порядок сохранён) +
  `options[:params]` (merge_get_params / merge_optional_params /
  add_current_page_param гема). `&` в href экранируется в `&amp;` — то же
  делает CGI.escapeHTML в самом геме.
- Вывод хелперов — `ActionView::SafeString` (аналог `html_safe`): ERB crails
  компилирует `<%= %>` в `__av_esc`, SafeString проходит без экранирования —
  `&#8592;`/`&hellip;`/`<b>` остаются сырыми.
- Вью-контекст crails — сам контроллер (`ActionController::Base include
  ActionView::Helpers`) с `request`/`params`; модуль объявляет
  `abstract def request : HTTP::Request`, который контроллер уже реализует.
- Вложенные `param_name` ("foo[page]") гем парсит через Rack — здесь имя
  ставится как есть.
- GET_PARAMS_BLACKLIST (:script_name) гема не нужен — в crails нет script_name.

## Интеграция с active_record.cr (crails, ~/rails.cr)

Порт `lib/will_paginate/active_record.rb` гема — опциональный файл
`src/will_paginate/active_record.cr` (не подключается главным require'ом;
в `development_dependencies` — active_record_cr по path):

```crystal
require "will_paginate_cr"
require "will_paginate/active_record"

@posts = Post.paginate(page: params["page"]?, per_page: 10)   # класс-модель
@posts = Post.where(published: true).order(:id).paginate(page: 2)  # скоуп
@comments = post.comments.paginate(page: 2, per_page: 5)      # ассоциация
```

- `paginate(page = 1, per_page = nil, total_entries = nil)` добавлен на
  `ActiveRecord::Base` (класс-метод), `Relation(T)` и `CollectionProxy(T)`.
- `page(num = 1, per_page = nil)` — stateless-порт `page` гема, на тех же
  трёх местах: ставит нативные поля Relation (offset/limit), возвращает
  `Relation(T)`. Чейн после него работает (`Post.page(2, per_page: 10)
  .where(...)`), но итог — обычный Array без метаданных пагинации.
- `Relation#per_page` — геттер (limit relation или per_page модели) и
  сеттер: `Post.page(3, per_page: 10).per_page(5)` пересчитывает offset
  под новый per_page (stateless: page = offset // limit + 1, если offset
  кратен limit; произвольный offset не трогается).
- `Relation#total_entries` — COUNT без ORDER BY/LIMIT/OFFSET (порт
  RelationMethods#total_entries; при GROUP BY — число групп).
- `Base.paginate_by_sql(sql, args:, page:, per_page:, total_entries:)` —
  postgres-ветка гема: LIMIT/OFFSET дописываются к SQL, COUNT —
  подзапросом с вырезанным ORDER BY (regex гема); колонки результата
  должны быть колонками модели (find_by_sql в active_record.cr нет,
  материализация через `__from_row_cols` + `rs.column_names`).
- Разрешение per_page как в геме: явный аргумент → `limit` текущего
  relation → `per_page` модели → `WillPaginate.per_page`. Per-классовое
  значение — переопределение `def self.per_page` в модели (гемовский
  `extend PerPage` в Crystal невозможен, см. per_page.cr).
- total_entries: явный аргумент → угадывание последней неполной страницы
  (магический `Collection#replace`, offset + size, без запроса) →
  COUNT-запрос без ORDER BY/LIMIT/OFFSET (`except(:order, :limit, :offset)`,
  как `count` гема); при GROUP BY — число групп.
- Предзагруженная (`includes`/`preload`) ассоциация пагинируется в памяти
  через `Array#paginate`, БД не трогается.

### Отличия от Ruby (статическая типизация)

- Гем возвращает из `paginate` Relation, расширенный на лету
  RelationMethods (`current_page`, `total_entries`, магический `to_a`);
  `Relation` в Crystal — иммутабельный struct: чейн-методы строят новый
  инстанс своим конструктором (`copy`/`rebuild` перечисляют только поля
  AR), и состояние, добавленное при reopen, в следующем звене цепочки
  не выживает (проверено репро: ивар добавляется, но сбрасывается в
  дефолт первым же `where`/`order`/`limit`). Поэтому `paginate`
  терминальный и сразу материализуется в `WillPaginate::Collection(T)`
  (Array с данными пагинации, совместим с вью-хелперами), а `page` —
  stateless (offset/limit без current_page).
- Чейн гема `Post.page(3).per_page(10)` работает через `per_page`-сеттер
  (см. выше) — но с stateless-пересчётом offset, а не через запомненный
  current_page: per_page передаётся аргументом в `page`/`paginate` или
  ставится методом `.per_page(n)` после `page`.

### Тестовая БД

`spec/active_record_spec.cr` использует отдельную БД (как crails_ar_test
у самого active_record.cr):

```
psql -h /var/run/postgresql -U root -d postgres -c 'create database crails_wp_test owner root'
```

Таблицы (posts 26 строк, comments) создаются спекой; атрибуты моделей
кодегенятся из `db/schema.yml` (в корне шарда).
