# frozen_string_literal: true

using OpenApiImportStringExt

module LibOpenApiImport
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
    name
  end

  def parameter_comment_lines(name, type, required, description)
    required_label = required.to_s == "true" ? "(required) " : ""
    label = "#{name.to_s.split(/\R/).join(" ")}: (#{type}) #{required_label}".rstrip
    desc_lines = description.to_s.split(/\R/)
    lines = ["#    #{label} #{desc_lines[0]}".rstrip]
    desc_lines.drop(1).each do |line|
      lines << "#\t\t\t#{line}" unless line.empty?
    end
    lines
  end
end
