require "yaml"

module WillPaginate
  # Порт i18n.rb. В Ruby гем использует ::I18n, если тот загружен, иначе
  # yield'ит блок-fallback. Здесь встроен мини-бэкенд с той же семантикой
  # перевода (defaults-цепочка, count-плорализация zero/one/other,
  # интерполяция %{name}); en-локаль поставляется из locale/en.yml (1:1
  # с гемом). Дополнительные переводы — через store_translations.
  module I18n
    alias Node = String | Hash(String, Node)
    alias Vars = Hash(String, String | Int32 | Int64 | Nil)

    DEFAULT_YAML = {{ read_file("#{__DIR__}/locale/en.yml") }}

    @@translations = {} of String => Node
    @@locale = "en"
    @@loaded = false

    def self.locale_dir : String
      {{ "#{__DIR__}/locale" }}
    end

    def self.load_path : Array(String)
      [File.join(locale_dir, "en.yml")]
    end

    def self.locale : String
      @@locale
    end

    def self.locale=(locale : String)
      @@locale = locale
    end

    # Записывает переводы в scope `will_paginate` указанной локали
    # (аналог `I18n.backend.store_translations :en, will_paginate: {...}`):
    #
    #   WillPaginate::I18n.store_translations("en",
    #     models: {post: {zero: "posts", one: "post", other: "posts"}})
    def self.store_translations(locale : String, tree : Hash) : Nil
      ensure_loaded
      root = (@@translations[locale]? || Hash(String, Node).new).as(Hash(String, Node))
      @@translations[locale] = root
      deep_merge(root, hash_to_node(tree).as(Hash(String, Node)))
    end

    # Две перегрузки — с блоком-fallback и без (аналог block_given? в Ruby:
    # вызов без блока при отсутствии перевода поднимает LocalJumpError).
    protected def self.translate(keys : Symbol | String | Array(String),
                                 vars : Vars = Vars.new, &block : String -> String) : String
      translate_or_raise(keys, vars, block)
    end

    protected def self.translate(keys : Symbol | String | Array(String),
                                 vars : Vars = Vars.new) : String
      translate_or_raise(keys, vars, nil)
    end

    private def self.translate_or_raise(keys : Symbol | String | Array(String), vars : Vars,
                                        block : Proc(String, String)?) : String
      ensure_loaded
      default_keys = keys.is_a?(Array(String)) ? keys : [keys.to_s]
      default_keys.each do |key|
        node = lookup(key)
        next unless node
        if vars.has_key?("count") && (hash = node.as?(Hash(String, Node)))
          node = select_plural(hash, vars["count"])
          next unless node
        end
        string = node.as?(String)
        next unless string
        return interpolate(string, vars)
      end
      if block
        block.call(default_keys.first)
      else
        # 1:1 со standalone-поведением гема: will_paginate_translate без
        # ::I18n и без блока → LocalJumpError.
        raise LocalJumpError.new("no block given (yield)")
      end
    end

    # Instance-метод, смешиваемый во вью-контекст (ViewHelpers включает
    # этот модуль; LinkRenderer зовёт его у @template).
    def will_paginate_translate(keys : Symbol | String | Array(String),
                                vars : I18n::Vars = I18n::Vars.new, &block : String -> String) : String
      I18n.translate(keys, vars, &block)
    end

    def will_paginate_translate(keys : Symbol | String | Array(String),
                                vars : I18n::Vars = I18n::Vars.new) : String
      I18n.translate(keys, vars)
    end

    def self.ensure_loaded : Nil
      return if @@loaded
      # корень каждой локали — поддерево scope `will_paginate`
      # (аналог `scope: :will_paginate` в переводе гема)
      YAML.parse(DEFAULT_YAML).as_h.each do |locale, subtree|
        scope = {} of String => Node
        @@translations[locale.to_s] = scope
        if (hash = subtree.as_h?) && (wp = hash["will_paginate"]?)
          if (wp_hash = wp.as_h?)
            wp_hash.each { |k, v| scope[k.to_s] = any_to_node(v) }
          end
        end
      end
      @@loaded = true
    end

    private def self.lookup(path : String) : Node?
      node : Node? = @@translations[@@locale]?
      path.split('.').each do |part|
        hash = node
        return nil unless hash.is_a?(Hash(String, Node))
        node = hash[part]?
      end
      node
    end

    private def self.select_plural(hash : Hash(String, Node), count : String | Int32 | Int64 | Nil)
      count_i = case count
                when Int32 then count
                when Int64 then count.to_i32
                else
                  nil
                end
      pick = count_i == 0 ? "zero" : (count_i == 1 ? "one" : "other")
      if (node = hash[pick]? || hash["other"]?)
        node
      else
        # Hash#values с рекурсивным алиасом ломает компилятор — берём
        # первый элемент вручную
        hash.each do |_key, value|
          return value
        end
        nil
      end
    end

    private def self.interpolate(template : String, vars : Vars) : String
      template.gsub(/%\{(\w+)\}/) do |match|
        value = vars[match[2..-2]]?
        value.nil? ? "" : value.to_s
      end
    end

    private def self.hash_to_node(value) : Node
      case value
      when Hash
        hash = {} of String => Node
        value.each { |k, v| hash[k.to_s] = hash_to_node(v) }
        hash
      when String
        value
      else
        value.to_s
      end
    end

    private def self.any_to_node(value : YAML::Any) : Node
      if (h = value.as_h?)
        hash = {} of String => Node
        h.each { |k, v| hash[k.to_s] = any_to_node(v) }
        hash
      else
        value.to_s
      end
    end

    private def self.deep_merge(target : Hash(String, Node), source : Hash(String, Node)) : Nil
      source.each do |key, value|
        existing = target[key]?
        if existing.is_a?(Hash(String, Node)) && value.is_a?(Hash(String, Node))
          deep_merge(existing, value)
        else
          target[key] = value
        end
      end
    end
  end
end
