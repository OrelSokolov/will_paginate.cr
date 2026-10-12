# will_paginate.cr

A Crystal port of [mislav/will_paginate](https://github.com/mislav/will_paginate)
**4.0.1** — the framework-independent pagination core (PageNumber,
Collection, view helpers, link renderer, i18n) plus optional
active_record.cr and action_view.cr integrations. Suite: 102 examples,
0 failures; view-helper output is byte-identical to the gem's oracle.

> ⚠️ EXPERIMENTAL — DO NOT USE IN PRODUCTION YET.

## Installation

```yaml
dependencies:
  will_paginate_cr:
    github: OrelSokolov/will_paginate.cr
```

```sh
shards install
```

## Usage

Framework-independent core:

```crystal
require "will_paginate_cr"

WillPaginate.per_page = 30
page = WillPaginate.page_number(3)      # Ruby: WillPaginate.PageNumber()
page.to_offset(10)                       # => 20

collection = WillPaginate::Collection(Post).create(3, 10, 26) { |pager|
  pager.replace(posts[20, 6])
}
```

Action View integration (optional require):

```crystal
require "will_paginate_cr"
require "will_paginate/view_helpers/action_view"

abstract class ApplicationController < ActionController::Base
  include WillPaginate::ActionView
end
```

```erb
<%= will_paginate @posts %>
<%= page_entries_info @posts, model: "post" %>
<%= paginated_section @posts do %> ... <% end %>
```

Active Record integration (optional require):

```crystal
require "will_paginate_cr"
require "will_paginate/active_record"

@posts = Post.paginate(page: params["page"]?, per_page: 10)          # model class
@posts = Post.where(published: true).order(:id).paginate(page: 2)    # scope
@comments = post.comments.paginate(page: 2, per_page: 5)             # association
```

## Feature comparison vs will_paginate 4.0.1

### Core

| Feature | Original (will_paginate) | Port (will_paginate.cr) | Status |
|---|---|---|---|
| `WillPaginate.per_page` / `per_page =` (default 30) | ✅ | Same (PerPage is an include module — no module-extend with ivars in Crystal; no inheritance hook) | 🔶 |
| `WillPaginate::PageNumber` (inspect `"page 3"`/`"offset 20"`, `to_offset`, `==`, `<=>`, arithmetic), `InvalidPage < ArgumentError` ("invalid page: 0"), `LocalJumpError` | ✅ | Same; `WillPaginate.page_number(value, name = "page")` replaces the Ruby method name `PageNumber()` | ✅ |
| `WillPaginate::Collection(T) < Array(T)` + `CollectionMethods`: current_page/per_page/total_entries/offset/total_pages/previous_page/next_page/out_of_bounds?, `create(page, per_page, total)`, magical `replace` with total_entries guessing | ✅ | Same | ✅ |
| `Array#paginate(page:, per_page:, total_entries:)` | ✅ | Same | ✅ |
| `WillPaginate::I18n` — scope `will_paginate`, defaults chain, zero/one/other pluralization, `%{name}` interpolation, en locale, `store_translations` | ✅ | Mini backend; translation keys are Strings (no `String#to_sym`) | 🔶 |
| `WillPaginate::Deprecation.warn`, `Deprecation::Hash#deprecate_key` | ✅ | Same | ✅ |
| core_ext monkeypatches (`String#underscore`, `Hash#except`) | ✅ | `WillPaginate.underscore` + internal except, no core monkeypatch | 🔶 |

### View helpers

| Feature | Original | Port | Status |
|---|---|---|---|
| `will_paginate(collection, **options)` — nil at ≤1 page; options class/previous_label/next_label/inner_window/outer_window/link_separator/param_name/page_links/container, extra options → container HTML attributes | ✅ | `renderer` is a positional argument (typed option hashes cannot store classes) | 🔶 |
| `page_entries_info(collection, model:, html:)` | ✅ | `model` only from the option (default `"entry"`) — `collection.first.class` is not reachable through the CollectionMethods interface | 🔶 |
| `LinkRendererBase` (`windowed_page_numbers`, `pagination`) and `LinkRenderer` (`to_html`, `container_attributes`, `page_number`/`gap`/`previous_page`/`next_page`/`html_container`/`tag`, `url` → NotImplementedError) | ✅ | Same | ✅ |
| ActionView integration: SafeString output, `&#8592;`/`&hellip;`/`<b>` stay raw; URL = request.path + GET params (page replaced in place, order preserved) + `options[:params]`; `&` escaped as `&amp;` | ✅ | Same, byte-identical oracle output | ✅ |
| Nested `param_name` ("foo[page]") parsed via Rack | ✅ | Set as-is | 🔶 |
| Mongoid/Sequel/Sinatra/Hanami integrations | ✅ | Not ported — their role is played by `LinkRenderer` subclasses with a custom `url(page)` | ❌ |

### ActiveRecord integration

| Feature | Original | Port | Status |
|---|---|---|---|
| `paginate(page:, per_page:, total_entries:)` on model class / Relation / association CollectionProxy | ✅ | Same three spots; terminal — materializes into `WillPaginate::Collection(T)` (Relation is an immutable struct in Crystal: chain methods rebuild the instance and reopen-added state does not survive the next link) | 🔶 |
| `page(num, per_page)` — stateless offset/limit | ✅ | Same; chainable (`Post.page(2, per_page: 10).where(...)`), result is a plain Relation without pagination metadata | ✅ |
| `Relation#per_page` getter/setter (recalculates offset for the new per_page) | ✅ | Stateless recalc: page = offset // limit + 1 when divisible; arbitrary offsets untouched | 🔶 |
| `Relation#total_entries` (COUNT without ORDER BY/LIMIT/OFFSET; groups count under GROUP BY) | ✅ | Same | ✅ |
| `paginate_by_sql(sql, args:, page:, per_page:, total_entries:)` — LIMIT/OFFSET appended, COUNT via subquery with ORDER BY stripped | ✅ | Postgres branch; result columns must be model columns (materialized via `__from_row_cols` + `rs.column_names`) | 🔶 |
| per_page resolution: explicit arg → relation limit → model `per_page` → global | ✅ | Same; per-class value = overriding `def self.per_page` | 🔶 |
| total_entries resolution: explicit → last-page guessing (no query) → COUNT | ✅ | Same | ✅ |
| Preloaded (`includes`/`preload`) association paginated in memory | ✅ | `Array#paginate`, DB untouched | ✅ |
| `paginate` returns a Relation extended on the fly (RelationMethods, magical `to_a`) | ✅ | See above — `paginate` is terminal and materializes | ❌ (equivalent: `Collection(T)` with full pagination data) |

## Deviations & Crystal-specific notes

- Options are typed (`OptionValue = Nil|Bool|Int32|String|Symbol|
  Hash(Symbol,String)`); `params : Hash(Symbol, String)`.
- Missing translation without a block raises
  `WillPaginate::LocalJumpError` ("no block given (yield)") — the gem's
  standalone behavior.

## Testing

```sh
# test DB for the active_record integration
psql -h /var/run/postgresql -U root -d postgres -c 'create database crails_wp_test owner root'
crystal spec   # 102 examples
```

- `spec/oracle_spec.cr` — 62 cases recorded from the real gem (plain
  Ruby view helpers + the gem's i18n for `page_entries_info`), replayed
  1:1.
- `spec/will_paginate_spec.cr` — units: Deprecation::Hash, global
  `pagination_options`, custom renderer/translations, PageNumber
  arithmetic, CollectionMethods.
- `spec/action_view_spec.cr` — ERB templates compiled by crails;
  pagination output byte-identical to the `wp_gaps` oracle case.
- `spec/active_record_spec.cr` — `paginate`/`page` on class/Relation/
  CollectionProxy against the `crails_wp_test` DB.
