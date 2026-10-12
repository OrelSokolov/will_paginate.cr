# Порт core_ext.rb гема: ActiveSupport-подобные String#underscore и
# Hash#except реализованы как функции модуля (без монкипатча String/Hash).

module WillPaginate
  # Скопировано из гема (lib/will_paginate/core_ext.rb), 1:1:
  def self.underscore(value : String) : String
    value
      .gsub("::", "/")
      .gsub(/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
      .gsub(/([a-z\d])([A-Z])/, "\\1_\\2")
      .tr("-", "_")
      .downcase
  end
end
