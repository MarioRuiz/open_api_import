module LibOpenApiImport
  #gen pretty hash symbolized
  private def pretty_hash_symbolized(hash)
    output = []
    output << "{"
    hash.each do |kr, kv|
      if kv.is_a?(Hash)
        restv = pretty_hash_symbolized(kv)
        restv[0] = "#{kr}: {"
        output += restv
      else
        output << "#{kr}: #{kv.inspect}, "
      end
    end
    output << "},"
    return output
  end
end
