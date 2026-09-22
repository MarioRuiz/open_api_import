# frozen_string_literal: true

module LibOpenApiImport
  private

  # gen pretty hash symbolized
  def pretty_hash_symbolized(hash)
    output = []
    output << "{"
    hash.each do |kr, kv|
      if kv.is_a?(Hash)
        restv = pretty_hash_symbolized(kv)
        restv[0] = "#{ruby_hash_key(kr)} {"
        output += restv
      else
        output << "#{ruby_hash_key(kr)} #{kv.inspect}, "
      end
    end
    output << "},"
    output
  end
end
