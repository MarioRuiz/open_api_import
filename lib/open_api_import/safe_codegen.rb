# frozen_string_literal: true

using OpenApiImportStringExt

module LibOpenApiImport
  RUBY_KEYWORDS = %w[
    BEGIN END alias and begin break case class def defined? do else elsif end
    ensure false for if in module next nil not or redo rescue retry return self
    super then true undef unless until when while yield
  ].freeze

  private

  # Prefix every physical line so spec text cannot terminate a Ruby comment.
  def comment_lines(text, prefix: "# ")
    text.to_s.split(/\R/).reject(&:empty?).map { |line| "#{prefix}#{line}" }
  end

  def ruby_constant_name(text, fallback: "Untitled")
    name = text.to_s.camel_case.gsub(/[^A-Za-z0-9_]/, "")
    name = fallback if name.empty?
    name = "C#{name}" unless name.match?(/\A[A-Z]/)
    name
  end

  def ruby_module_version(text, fallback: "V0")
    name = "V#{text.to_s.snake_case}".gsub(/[^A-Za-z0-9_]/, "")
    name = fallback if name.empty? || name == "V"
    name
  end

  def ruby_method_name(text, preserve_case: false, fallback: "undefined")
    source = text.to_s.split(/\R/).join("_")
    name = if preserve_case
             source.gsub(/[^A-Za-z0-9_]/, "")
           else
             source.snake_case.gsub(/[^a-z0-9_]/, "")
           end
    name = fallback if name.empty?
    name = "_#{name}" unless name.match?(/\A[A-Za-z_]/)
    name = "#{name}_" if RUBY_KEYWORDS.include?(name)
    name
  end

  def ruby_parameter_name(text, fallback: "parameter")
    ruby_method_name(text, fallback: fallback)
  end

  def ruby_environment_constant(text)
    name = ruby_parameter_name(text).upcase
    name = "C#{name}" unless name.match?(/\A[A-Z]/)
    name
  end

  def ruby_hash_key(text)
    name = text.to_s
    if name.match?(/\A[A-Za-z_][A-Za-z0-9_]*\z/) && !RUBY_KEYWORDS.include?(name)
      "#{name}:"
    else
      "#{name.inspect} =>"
    end
  end

  def ruby_symbol_key(text)
    "#{text.to_s.inspect}:"
  end

  def ruby_symbol_literal(text)
    text.to_s.to_sym.inspect
  end

  # String#inspect escapes interpolation. Re-enable only placeholders that were
  # generated from identifiers already reduced to Ruby local-variable syntax.
  def ruby_interpolated_string(text, variable_names)
    literal = text.to_s.inspect
    variable_names.uniq.each do |name|
      token = format("\#{%s}", name)
      literal = literal.gsub("\\#{token}", token)
    end
    literal
  end

  def parameter_comment_lines(name, type, required, description)
    required_label = required.to_s == "true" ? "(required) " : ""
    rendered = "#{name}: (#{type}) #{required_label}#{description}".rstrip
    comment_lines(rendered, prefix: "#    ")
  end
end
