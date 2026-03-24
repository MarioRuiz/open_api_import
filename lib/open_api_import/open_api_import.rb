# frozen_string_literal: true

using OpenApiImportStringExt

class OpenApiImport
  class ParseError < StandardError; end

  VERSION = "0.12.0"

  extend LibOpenApiImport

  ##############################################################################################
  # Import a Swagger or Open API file and create a Ruby Request Hash file including all requests and responses.
  # The http methods that will be treated are: 'get','post','put','delete', 'patch'.
  # @param swagger_file [String]. Path and file name. Could be absolute or relative to project root folder.
  # @param include_responses [Boolean]. (default: true) if you want to add the examples of responses in the resultant file.
  # @param mock_response [Boolean]. (default:false) Add the first response on the request as mock_response to be used.
  #   In case using nice_http gem: if NiceHttp.use_mocks = true will use it instead of getting the real response from the WS.
  # @param create_method_name [Symbol]. (:path, :operation_id, :operationId) (default: operation_id). How the name of the methods will be generated.
  #   path: it will be used the path and http method, for example for a GET on path: /users/list, the method name will be get_users_list
  #   operation_id: it will be used the operationId field but using the snake_case version, for example for listUsers: list_users
  #   operationId: it will be used the operationId field like it is, for example: listUsers
  # @param name_for_module [Symbol]. (:path, :path_file, :fixed, :tags, :tags_file) (default: :path). How the module names will be created.
  # @param create_constants [Boolean]. (default: false) For required arguments, it will create keyword arguments assigning by default a constant.
  # @param silent [Boolean]. (default: false) It will display only errors.
  #   path: It will be used the first folder of the path to create the module name, for example the path /users/list will be in the module Users and all the requests from all modules in the same file.
  #   path_file: It will be used the first folder of the path to create the module name, for example the path /users/list will be in the module Users and each module will be in a new requests file.
  #   tags: It will be used the tags key to create the module name, for example the tags: [users,list] will create the module UsersList and all the requests from all modules in the same file.
  #   tags_file: It will be used the tags key to create the module name, for example the tags: [users,list] will create the module UsersList and and each module will be in a new requests file.
  #   fixed: all the requests will be under the module Requests
  # @param return_data [Boolean]. (default: false) Instead of writing files, return a Hash of {filename => content}.
  ##############################################################################################
  def self.from(swagger_file, create_method_name: :operation_id, include_responses: true, mock_response: false,
                name_for_module: :path, silent: false, create_constants: false, return_data: false)
    begin
      f = File.new("#{swagger_file}_open_api_import.log", "w")
      f.sync = true
      @logger = Logger.new f
      puts "Logs file: #{swagger_file}_open_api_import.log" unless silent
    rescue StandardError => e
      warn "Not possible to create the Logger file"
      warn e
      @logger = Logger.new nil
    end

    begin
      @logger.info "swagger_file: #{swagger_file}, include_responses: #{include_responses}, mock_response: #{mock_response}\n"
      @logger.info "create_method_name: #{create_method_name}, name_for_module: #{name_for_module}\n"

      file_to_convert = File.expand_path(swagger_file)
      unless File.exist?(file_to_convert)
        raise "The file #{file_to_convert} doesn't exist"
      end

      file_errors = "#{file_to_convert}.errors.log"
      FileUtils.rm_f(file_errors)
      import_errors = ""
      required_constants = []

      begin
        definition = OasParser::Definition.resolve(swagger_file)
      rescue StandardError => e
        message = "There was a problem parsing the Open Api document using the oas_parser_reborn gem. The execution was aborted.\n"
        message += "Visit the github for oas_parser_reborn gem for bugs and more info: https://github.com/MarioRuiz/oas_parser_reborn\n"
        message += "Error: #{e.message}"
        @logger.fatal message
        @logger.fatal e.backtrace.join("\n")
        raise ParseError, message
      end

      raw = definition.raw.deep_symbolize_keys

      if raw.key?(:openapi) && raw[:openapi].to_f.positive?
        raw[:swagger] = raw[:openapi]
      end
      if raw[:swagger].to_f < 2.0
        raise "Unsupported Swagger version. Only versions >= 2.0 are valid."
      end

      base_path = ""

      raw[:host] if raw.key?(:host)
      base_path = raw[:basePath] if raw.key?(:basePath)
      module_name = raw[:info][:title].camel_case
      module_version = "V#{raw[:info][:version].to_s.snake_case}"

      output = []
      output_header = []
      output_header << ("#" * 50)
      output_header << "# #{raw[:info][:title]}"
      output_header << "# version: #{raw[:info][:version]}"
      output_header << "# description: "
      raw[:info][:description].to_s.split("\n").each do |d|
        output_header << "#     #{d}" unless d == ""
      end
      output_header << ("#" * 50)

      output_header << "module Swagger"
      output_header << "module #{module_name}"
      output_header << "module #{module_version}"
      output_header << "module Requests" if name_for_module == :fixed

      files = {}

      module_requests = ""

      definition.paths.each do |path|
        raw = path.raw.deep_symbolize_keys

        if raw.key?(:parameters)
          raw.each_key do |met|
            if met != :parameters
              if raw[met].key?(:parameters)
                raw[met][:parameters] = raw[met][:parameters] + raw[:parameters]
              else
                raw[met][:parameters] = raw[:parameters]
              end
            end
          end
          raw.delete(:parameters)
        end

        raw.each do |met, cont|
          if %w[get post put delete patch].include?(met.to_s.downcase)
            params = []
            params_path = []
            params_query = []
            params_required = []
            params_data = []
            description_parameters = []
            data_form = []
            data_form_hash = {}
            data_required = []
            data_read_only = []
            data_default = []
            data_examples = []
            data_examples_hashes = []
            data_pattern = []
            responses = []

            cont[:operationId] = "undefined" unless cont.key?(:operationId)

            if create_method_name == :path
              method_name = "#{met}_#{path.path}".snake_case
              method_name.chop! if method_name[-1] == "_"
            elsif create_method_name == :operation_id
              if ((name_for_module == :tags) || (name_for_module == :tags_file)) && cont.key?(:tags) && cont[:tags].is_a?(Array) && cont[:tags].size.positive?
                metnametmp = cont[:operationId].gsub(/^#{cont[:tags].join}[\s_]*/, "")
                cont[:tags].join.split.each do |tag|
                  metnametmp = metnametmp.gsub(/^#{tag}[\s_]*/i, "")
                end
                metnametmp = met if metnametmp == ""
              else
                metnametmp = cont[:operationId]
              end
              method_name = metnametmp.to_s.snake_case
            elsif ((name_for_module == :tags) || (name_for_module == :tags_file)) && cont.key?(:tags) && cont[:tags].is_a?(Array) && cont[:tags].size.positive?
              method_name = cont[:operationId].gsub(/^#{cont[:tags].join}[\s_]*/, "")
              cont[:tags].join.split.each do |tag|
                method_name = method_name.gsub(/^#{tag}[\s_]*/i, "")
              end
              method_name = met if method_name == ""
            else
              method_name = cont[:operationId]
            end
            path_txt = path.path.dup.to_s
            if [:path, :path_file, :tags, :tags_file].include?(name_for_module)
              old_module_requests = module_requests
              if [:path, :path_file].include?(name_for_module)
                path_requests = path_txt.gsub(%r{^/v[\d\.]*/}i, "")
                path_requests = path_requests.gsub(%r{^/[\d\.]*/}i, "")
                if (path_requests == path_txt) && (path_txt.scan("/").size == 1)
                  module_requests = "Root"
                else
                  res_path = path_requests.scan(/(\w+)/)
                  module_requests = res_path[0][0].camel_case
                end
              elsif cont.key?(:tags) && cont[:tags].is_a?(Array) && cont[:tags].size.positive?
                module_requests = cont[:tags].join(" ").camel_case
              else
                module_requests = "Undefined"
              end

              if /^(?<vers>v\d+)/i =~ method_name
                method_name = method_name.gsub(/^#{vers}_?/, "")
                module_requests = (vers.capitalize + module_requests).camel_case unless module_requests.start_with?(vers)
              end

              if old_module_requests != module_requests
                output << "end" unless (old_module_requests == "") || (name_for_module == :path_file) || (name_for_module == :tags_file)
                if (name_for_module == :path) || (name_for_module == :tags)
                  output << "module #{module_requests}"
                else # :path_file, :tags_file
                  if old_module_requests != ""
                    unless files.key?(old_module_requests)
                      files[old_module_requests] = []
                    end
                    files[old_module_requests].concat(output)
                    output = []
                  end
                  output << "module #{module_requests}" unless files.key?(module_requests)
                end
              end
            end

            output << ""
            output << "# operationId: #{cont[:operationId]}, method: #{met}"
            output << "# summary: #{cont[:summary].split("\n").join("\n#          ")}" if cont.key?(:summary)
            if cont[:description].to_s.split("\n").empty?
              output << "# description: #{cont[:description]}"
            else
              output << "# description: "
              cont[:description].to_s.split("\n").each do |d|
                output << "#     #{d}" unless d == ""
              end
            end

            mock_example = []

            if include_responses && cont.key?(:responses) && cont[:responses].is_a?(Hash)
              cont[:responses].each do |k, v|
                response_example = get_response_examples(v)

                data_pattern += get_patterns("", v[:schema]) if v.key?(:schema)
                data_pattern.uniq!
                resp_description = v[:description].to_s.gsub("'", %q(\\\'))
                if response_example.empty?
                  responses << "'#{k}': { message: '#{resp_description}'}, "
                else
                  responses << "'#{k}': { "
                  responses << "message: '#{resp_description}', "
                  responses << "data: "
                  responses << response_example
                  responses << "},"
                  if mock_response && mock_example.empty?
                    mock_example << "code: '#{k}',"
                    mock_example << "message: '#{resp_description}',"
                    mock_example << "data: "
                    mock_example << response_example
                  end
                end
              end
            end

            if cont.key?(:requestBody) && cont[:requestBody].key?(:content) &&
               cont[:requestBody][:content].key?(:"application/json") && cont[:requestBody][:content][:"application/json"].key?(:schema)
              cont[:parameters] = [] unless cont.key?(:parameters)
              cont[:parameters] << { in: "body", schema: cont[:requestBody][:content][:"application/json"][:schema] }
            end

            data_examples_all_of = false
            if cont.key?(:parameters) && cont[:parameters].is_a?(Array)
              cont[:parameters].each do |p|
                if p.keys.include?(:schema) && p[:schema].include?(:type)
                  type = p[:schema][:type]
                  type = Array(type).reject { |t| t == "null" }.first if type.is_a?(Array)
                elsif p.keys.include?(:type)
                  type = p[:type]
                  type = Array(type).reject { |t| t == "null" }.first if type.is_a?(Array)
                else
                  type = ""
                end

                if p[:in] == "path"
                  if create_method_name == :operationId
                    param_name = p[:name]
                    path_txt = path_txt.gsub("{#{param_name}}", "\#{#{param_name}}")
                  else
                    param_name = p[:name].to_s.snake_case
                    path_txt = path_txt.gsub("{#{p[:name]}}", "\#{#{param_name}}")
                  end
                  unless params_path.include?(param_name)
                    if create_constants
                      params_path << "#{param_name}: #{param_name.upcase}"
                      required_constants << param_name.upcase
                    else
                      params_path << param_name
                    end
                    @logger.warn "Description key is missing for #{met} #{path.path} #{p[:name]}" if p[:description].nil?
                    description_parameters << "#    #{p[:name]}: (#{type}) #{"(required)" if p[:required].to_s == "true"} #{p[:description].to_s.split("\n").join("\n#\t\t\t")}"
                  end
                elsif p[:in] == "query"
                  params_query << p[:name]
                  params_required << p[:name] if p[:required].to_s == "true"
                  @logger.warn "Description key is missing for #{met} #{path.path} #{p[:name]}" if p[:description].nil?
                  description_parameters << "#    #{p[:name]}: (#{type}) #{"(required)" if p[:required].to_s == "true"} #{p[:description].to_s.split("\n").join("\n#\t\t\t")}"
                elsif (p[:in] == "formData") || (p[:in] == "formdata")
                  description_parameters << "#    #{p[:name]}: (#{p[:type]}) #{p[:description].split("\n").join("\n#\t\t\t")}"

                  case p[:type]
                  when /^string$/i
                    data_form << "#{p[:name]}: ''"
                    data_form_hash[p[:name].to_sym] = ""
                  when /^boolean$/i
                    data_form << "#{p[:name]}: true"
                    data_form_hash[p[:name].to_sym] = true
                  when /^number$/i
                    data_form << "#{p[:name]}: 0"
                    data_form_hash[p[:name].to_sym] = 0
                  when /^integer$/i
                    data_form << "#{p[:name]}: 0"
                    data_form_hash[p[:name].to_sym] = 0
                  else
                    puts "! on formData not supported type #{p[:type]}"
                  end
                elsif p[:in] == "body"
                  if p.keys.include?(:schema)
                    if p[:schema].key?(:oneOf)
                      bodies = p[:schema][:oneOf]
                    elsif p[:schema].key?(:anyOf)
                      bodies = p[:schema][:anyOf]
                    elsif p[:schema].key?(:allOf)
                      data_examples_all_of, bodies = get_data_all_of_bodies(p)
                      bodies.unshift(p[:schema]) if p[:schema].key?(:required) || p.key?(:required)
                      data_examples_all_of = true
                    else
                      bodies = [p[:schema]]
                    end

                    params_data = []
                    params_data_hash = {}

                    bodies.each do |body|
                      data_required += get_required_data(body)
                      all_properties = []
                      all_properties << body[:properties] if body.keys.include?(:properties) && body[:properties].size.positive?
                      if body.key?(:allOf)
                        body[:allOf].each do |item|
                          all_properties << item[:properties] if item.key?(:properties)
                        end
                      end

                      all_properties.each do |props|
                        props.each do |dpk, dpv|
                          if dpv.keys.include?(:example)
                            if dpv[:example].is_a?(Array) && (dpv.type != "array")
                              valv = dpv[:example][0]
                            else
                              valv = dpv[:example].to_s
                            end
                          elsif dpv.type == "object"
                            if dpv.key?(:properties)
                              valv = get_examples(dpv[:properties], :key_value, true).join("\n")
                            else
                              valv = "{}"
                            end
                          elsif dpv.type == "array"
                            if dpv.key?(:items)
                              valv = get_examples({ dpk => dpv }, :only_value)
                              valv = valv.join("\n")
                            else
                              valv = "[]"
                            end
                          else
                            valv = ""
                          end

                          if dpv.keys.include?(:description)
                            description_parameters << "#    #{dpk}: (#{dpv[:type]}) #{dpv[:description].split("\n").join("\n#\t\t\t")}"
                          end

                          data_pattern += get_patterns(dpk, dpv)
                          data_pattern.uniq!
                          dpkeys = []
                          data_pattern.reject! do |dp|
                            dpkey = dp.scan(/^'[\w\.]+'/)

                            if dpkeys.include?(dpkey)
                              true
                            else
                              dpkeys << dpkey
                              false
                            end
                          end

                          if dpv.keys.include?(:readOnly) && (dpv[:readOnly] == true)
                            data_read_only << dpk
                          end
                          if dpv.keys.include?(:default)
                            if dpv[:default].nil?
                              data_default << "#{dpk}: nil"
                            elsif dpv.type != "string"
                              data_default << "#{dpk}: #{dpv[:default]}"
                            else
                              data_default << "#{dpk}: '#{dpv[:default]}'"
                            end
                          end

                          params_data_hash[dpk] = build_example_value(dpv)

                          if dpv.key?(:type) && (dpv[:type] != "array")
                            params_data << get_examples({ dpk => dpv }, :only_value, true).join
                            params_data[-1].chop!.chop! if params_data[-1].to_s[-2..] == ", "
                            params_data.pop if params_data[-1].match?(/^\s*$/im)
                          else
                            if valv.to_s == ""
                              valv = '""'
                            elsif valv.include?('"')
                              valv = valv.gsub('"', "'") unless valv.include?("'")
                            end
                            params_data << "#{dpk}: #{valv}"
                          end
                        end
                        if params_data.size.positive?
                          if (data_examples_all_of == true) && data_examples.size.positive?
                            data_examples[0] += params_data
                          else
                            data_examples << params_data
                          end
                          if (data_examples_all_of == true) && data_examples_hashes.size.positive?
                            data_examples_hashes[0].merge!(params_data_hash)
                          else
                            data_examples_hashes << params_data_hash.dup
                          end
                          params_data = []
                          params_data_hash = {}
                        end
                      end
                    end

                    unless data_required.empty?
                      data_required.uniq!
                      output << "# required data: #{data_required.inspect}"
                    end
                  end
                elsif p[:in] == "header"
                  # TODO: see how we can treat those cases
                else
                  puts "! not imported data with :in:#{p[:in]} => #{p.inspect}"
                end
              end

              params = params_path

              unless params_query.empty?
                path_txt += "?"
                params_required.each do |pr|
                  if create_constants
                    if params_query.include?(pr)
                      if create_method_name == :operationId
                        path_txt += "#{pr}=\#{#{pr}}&"
                        params << "#{pr}: #{pr.upcase}"
                        required_constants << pr.upcase
                      else
                        path_txt += "#{pr}=\#{#{pr.to_s.snake_case}}&"
                        params << "#{pr.to_s.snake_case}: #{pr.to_s.snake_case.upcase}"
                        required_constants << pr.to_s.snake_case.upcase
                      end
                    end
                  elsif params_query.include?(pr)
                    if create_method_name == :operationId
                      path_txt += "#{pr}=\#{#{pr}}&"
                      params << pr.to_s
                    else
                      path_txt += "#{pr}=\#{#{pr.to_s.snake_case}}&"
                      params << pr.to_s.snake_case.to_s
                    end
                  end
                end
                params_query.each do |pq|
                  unless params_required.include?(pq)
                    if create_method_name == :operationId
                      path_txt += "#{pq}=\#{#{pq}}&"
                      params << "#{pq}: ''"
                    else
                      path_txt += "#{pq}=\#{#{pq.to_s.snake_case}}&"
                      params << "#{pq.to_s.snake_case}: ''"
                    end
                  end
                end
              end
            end

            if description_parameters.size.positive?
              output << "# parameters description: "
              output << description_parameters.uniq
            end

            if path_txt.scan(/[^#]{\w+}/).size.positive?
              paramst = []
              prms = path_txt.scan(/[^#]{(\w+)}/)
              prms.each do |p|
                paramst << p[0].to_s.snake_case
                path_txt = path_txt.gsub("{#{p[0]}}", "\#{#{p[0].to_s.snake_case}}")
              end
              paramst.concat params
              params = paramst
            end
            params.uniq!
            output << "def self.#{method_name} (#{params.join(", ")})"

            output << "{"

            output << "name: \"#{module_requests}.#{method_name}\","

            output << "path: \"#{base_path}#{path_txt}\","

            output << "method: :#{met}," if met.to_s != ""

            unless data_required.empty?
              output << "data_required: ["
              output << ":'#{data_required.uniq.join("', :'")}'"
              output << "],"
            end
            unless data_read_only.empty?
              output << "data_read_only: ["
              output << ":'#{data_read_only.uniq.join("', :'")}'"
              output << "],"
            end
            unless data_default.empty?
              output << "data_default: {"
              data_default.uniq!
              output << data_default.join(", \n")
              output << "},"
            end

            unless data_pattern.empty?
              output << "data_pattern: {"
              output << data_pattern.uniq.join(", \n")
              output << "},"
            end

            unless data_form.empty?
              data_examples << data_form
              data_examples_hashes << data_form_hash unless data_form_hash.empty?
            end

            unless data_examples.empty?
              unless data_required.empty?
                reqdata = []
                begin
                  data_examples[0].uniq!
                  data_ex = data_examples_hashes[0] || {}
                rescue StandardError => e
                  data_ex = {}
                  @logger.warn "Error processing data examples: #{met} for path: #{path.path} => #{e.message}"
                end
                if data_required.grep(/\./).empty?
                  reqdata = filter(data_ex, data_required)
                else
                  reqdata = filter(data_ex, data_required, true)
                end
                unless reqdata.empty?
                  reqdata.uniq!
                  phsd = pretty_hash_symbolized(reqdata)
                  phsd[0] = "data: {"
                  output += phsd
                end
              end
              unless data_read_only.empty? || !data_required.empty?
                reqdata = []
                data_examples[0].each do |edata|
                  read_only = false
                  data_read_only.each do |rdata|
                    if edata.scan(/^#{rdata}:/).size.positive?
                      read_only = true
                      break
                    elsif edata.scan(":").empty?
                      break
                    end
                  end
                  reqdata << edata unless read_only
                end
                unless reqdata.empty?
                  reqdata.uniq!
                  output << "data: {"
                  output << reqdata.join(", \n")
                  output << "},"
                end
              end

              output << "data_examples: ["
              data_examples.each do |data|
                output << "{"
                data.uniq!
                output << data.join(", \n")
                output << "}, "
              end
              output << "],"
            end

            unless mock_example.empty?
              output << "mock_response: {"
              output << mock_example
              output << "},"
            end

            unless responses.empty?
              output << "responses: {"
              output << responses
              output << "},"
            end

            output << "}"
            output << "end"
          else
            @logger.warn "Not imported method: #{met} for path: #{path.path} since it is not supported by OpenApiImport"
          end
        end
      end
      output_footer = []

      output_footer << "end" unless (module_requests == "") && [:path, :path_file, :tags, :tags_file].include?(name_for_module)
      output_footer << "end" << "end" << "end"

      generated_files = {}

      if files.empty? && !create_constants
        output = output_header + output + output_footer
        output_txt = output.join("\n")
        requests_file_path = "#{file_to_convert}.rb"
        if return_data
          generated_files[requests_file_path] = output_txt
        else
          File.write(requests_file_path, output_txt)
          format_and_check_file(requests_file_path, @logger)
          message = "** Requests file: #{swagger_file}.rb that contains the code of the requests after importing the Swagger file"
          puts message unless silent
          @logger.info message
        end
      else
        unless files.key?(module_requests)
          files[module_requests] = []
        end
        files[module_requests].concat(output)

        requires_txt = ""
        message = "** Generated files that contain the code of the requests after importing the Swagger file: "
        puts message unless silent
        @logger.info message
        files.each do |mod, out_mod|
          output = output_header + out_mod + output_footer
          output_txt = output.join("\n")
          requests_file_path = "#{file_to_convert}_#{mod}.rb"
          requires_txt += "require_relative '#{File.basename(swagger_file)}_#{mod}'\n"
          if return_data
            generated_files[requests_file_path] = output_txt
          else
            File.write(requests_file_path, output_txt)
            format_and_check_file(requests_file_path, @logger)
            display_path = "#{swagger_file}_#{mod}.rb"
            message = "  - #{display_path}"
            puts message unless silent
            @logger.info message
          end
        end

        requests_file_path = "#{file_to_convert}.rb"
        if required_constants.size.positive?
          rconsts = "# Required constants\n"
          required_constants.uniq!
          required_constants.each do |rq|
            rconsts += "#{rq} ||= ENV['#{rq}'] ||=''\n"
          end
          rconsts += "\n\n"
        else
          rconsts = ""
        end

        if return_data
          generated_files[requests_file_path] = rconsts + requires_txt
        else
          File.write(requests_file_path, rconsts + requires_txt)
          format_and_check_file(requests_file_path, @logger)
          message = "** File that contains all the requires for all Request files: \n"
          message += "   - #{swagger_file}.rb "
          puts message unless silent
          @logger.info message
        end
      end

      return generated_files if return_data

      begin
        load File.expand_path(requests_file_path)
      rescue StandardError => e
        import_errors += "\n\nResult evaluating the ruby file generated: \n#{e}"
      end

      if import_errors.to_s == ""
        true
      else
        File.write(file_errors, import_errors)
        message = "* It seems there was a problem importing the Swagger file #{swagger_file}\n"
        message += "* Take a look at the detected errors at #{file_errors}\n"
        warn message
        @logger.fatal message
        false
      end
    rescue ParseError
      raise
    rescue StandardError => e
      puts e.message
      @logger.fatal e.message
      @logger.fatal e.backtrace
      puts e.backtrace
    end
  end

  private_class_method def self.format_and_check_file(file_path, logger)
    escaped_path = Shellwords.shellescape(file_path)
    res_rufo = `rufo #{escaped_path}`
    logger.error "       Error formatting with rufo" unless res_rufo.to_s.match?(/\AFormat:.+$\s*\z/)
    syntax_result = `ruby -c #{escaped_path} 2>&1`
    logger.error "       Syntax Error: #{syntax_result}" unless syntax_result.include?("Syntax OK")
  rescue Errno::ENOENT => e
    logger.error "       Could not run formatter/syntax checker: #{e.message}"
  end

  private_class_method def self.build_example_value(dpv)
    if dpv.key?(:example)
      dpv[:example]
    elsif dpv.key?(:examples) && dpv[:examples].is_a?(Array) && !dpv[:examples].empty?
      dpv[:examples].first
    elsif dpv.key?(:type)
      effective_type = dpv[:type]
      effective_type = Array(effective_type).reject { |t| t == "null" }.first if effective_type.is_a?(Array)
      case effective_type.to_s.downcase
      when "string" then dpv[:format] || "string"
      when "integer" then 0
      when "number"
        %w[float double decimal].include?(dpv[:format].to_s.downcase) ? 0.0 : 0
      when "boolean" then true
      when "object"
        if dpv.key?(:properties)
          result = {}
          dpv[:properties].each { |k, v| result[k] = build_example_value(v) }
          result
        else
          {}
        end
      when "array"
        if dpv.key?(:items) && dpv[:items].is_a?(Hash)
          [build_example_value(dpv[:items])]
        else
          []
        end
      else dpv[:format] || ""
      end
    else
      ""
    end
  end
end
