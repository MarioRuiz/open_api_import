# frozen_string_literal: true

module OpenApiImportStringExt
  refine String do
    def snake_case
      gsub(/\W/, "_")
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        .gsub(/([a-z])([A-Z])/, '\1_\2')
        .downcase
        .gsub(/_+/, "_")
    end

    def camel_case
      return self if self =~ /\A[A-Z][A-Za-z0-9]*\z/

      gsub(/\W/, "_")
        .split("_").map(&:capitalize).join
    end
  end
end
