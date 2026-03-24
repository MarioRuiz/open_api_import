require "open_api_import"

RSpec.describe LibOpenApiImport do
  let(:helper) do
    obj = Object.new
    obj.extend(LibOpenApiImport)
    obj
  end

  describe "#get_examples" do
    it "handles string type properties" do
      properties = { name: { type: "string" } }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("name:")
      expect(result.join).to include('"string"')
    end

    it "handles integer type properties" do
      properties = { age: { type: "integer" } }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("age: 0")
    end

    it "handles number type with float format" do
      properties = { price: { type: "number", format: "float" } }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("price: 0.0")
    end

    it "handles number type with double format" do
      properties = { amount: { type: "number", format: "double" } }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("amount: 0.0")
    end

    it "handles number type with decimal format" do
      properties = { rate: { type: "number", format: "decimal" } }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("rate: 0.0")
    end

    it "handles number type without float/double format" do
      properties = { count: { type: "number" } }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("count: 0")
    end

    it "handles boolean type properties" do
      properties = { active: { type: "boolean" } }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("active: true")
    end

    it "uses example values when provided" do
      properties = { name: { type: "string", example: "John" } }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("John")
    end

    it "uses numeric example values directly" do
      properties = { age: { type: "integer", example: 42 } }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("42")
    end

    it "uses examples (plural, OAS 3.1) when example is absent" do
      properties = { name: { type: "string", examples: ["Fido", "Rex"] } }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("Fido")
    end

    it "prefers example over examples (plural)" do
      properties = { name: { type: "string", example: "Buddy", examples: ["Fido"] } }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("Buddy")
      expect(result.join).not_to include("Fido")
    end

    it "handles string example containing single quotes" do
      properties = { desc: { type: "string", example: "it's a test" } }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("it's a test")
    end

    it "replaces double quotes with single quotes in string examples" do
      properties = { desc: { type: "string", example: 'say "hello"' } }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("say 'hello'")
    end

    it "handles Time example values" do
      time_val = Time.new(2024, 1, 15)
      properties = { created: { type: "string", example: time_val } }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("2024")
    end

    it "handles array example that is Array but type is string (takes first)" do
      properties = { tag: { type: "string", example: ["alpha", "beta"] } }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("alpha")
    end

    it "skips readOnly properties when remove_readonly is true" do
      properties = {
        id: { type: "integer", readOnly: true },
        name: { type: "string" },
      }
      result = helper.send(:get_examples, properties, :key_value, true)
      expect(result.join).not_to include("id:")
      expect(result.join).to include("name:")
    end

    it "includes readOnly properties when remove_readonly is false" do
      properties = {
        id: { type: "integer", readOnly: true },
        name: { type: "string" },
      }
      result = helper.send(:get_examples, properties, :key_value, false)
      expect(result.join).to include("id:")
      expect(result.join).to include("name:")
    end

    it "returns only values when type is :only_value" do
      properties = { name: { type: "string" } }
      result = helper.send(:get_examples, properties, :only_value)
      expect(result.join).not_to include("{")
      expect(result.join).not_to include("}")
    end

    it "wraps in braces for :key_value type" do
      properties = { name: { type: "string" } }
      result = helper.send(:get_examples, properties, :key_value)
      expect(result.first).to eq("{")
      expect(result.last).to eq("}")
    end

    it "handles array type with enum items" do
      properties = {
        status: {
          type: "array",
          items: { type: "string", enum: ["active", "inactive"] },
        },
      }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("active")
    end

    it "handles array with single-type items (no enum)" do
      properties = {
        tags: {
          type: "array",
          items: { type: "string" },
        },
      }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("tags:")
      expect(result.join).to include("string")
    end

    it "handles array enum items with :only_value type" do
      properties = {
        status: {
          type: "array",
          items: { type: "string", enum: ["active", "inactive"] },
        },
      }
      result = helper.send(:get_examples, properties, :only_value)
      expect(result.join).to include("active")
      expect(result.join).not_to include("status:")
    end

    it "infers object type from :properties key when no explicit type" do
      properties = {
        address: {
          properties: { city: { type: "string" } },
        },
      }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("address:")
    end

    it "infers array type from :items key when no explicit type" do
      properties = {
        tags: {
          items: { type: "string", enum: ["a", "b"] },
        },
      }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("tags:")
    end

    it "handles nullable type arrays (OAS 3.1)" do
      properties = { name: { type: ["string", "null"] } }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("name:")
      expect(result.join).to include('"string"')
    end

    it "returns empty array for empty properties" do
      result = helper.send(:get_examples, {})
      expect(result).to eq([])
    end

    it "handles object type with no properties" do
      properties = { meta: { type: "object" } }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("meta:")
      expect(result.join).to include("{ }")
    end

    it "handles unknown type by using format as value" do
      properties = { field: { type: "custom", format: "special" } }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("special")
    end

    it "handles string type with format (uses format as placeholder)" do
      properties = { email: { type: "string", format: "email" } }
      result = helper.send(:get_examples, properties)
      expect(result.join).to include("email")
    end
  end

  describe "#get_response_examples" do
    it "handles v2.0 string examples (application/json)" do
      v = {
        examples: {
          'application/json': '{"name": "test"}',
        },
      }
      result = helper.send(:get_response_examples, v)
      expect(result).not_to be_empty
      expect(result.first).to include("test")
    end

    it "handles v2.0 hash examples (application/json)" do
      v = {
        examples: {
          'application/json': { name: "test", id: 1 },
        },
      }
      result = helper.send(:get_response_examples, v)
      expect(result).not_to be_empty
      expect(result.join).to include("name")
    end

    it "handles v2.0 array examples (application/json)" do
      v = {
        examples: {
          'application/json': [{ name: "a" }, { name: "b" }],
        },
      }
      result = helper.send(:get_response_examples, v)
      expect(result).not_to be_empty
      expect(result.first).to eq("[")
      expect(result.last).to eq("]")
    end

    it "handles v3.0 content -> application/json -> schema with properties" do
      v = {
        content: {
          'application/json': {
            schema: {
              properties: {
                name: { type: "string" },
                age: { type: "integer" },
              },
            },
          },
        },
      }
      result = helper.send(:get_response_examples, v)
      expect(result).not_to be_empty
      expect(result.join).to include("name:")
      expect(result.join).to include("age:")
    end

    it "handles v3.0 content -> examples (hash value)" do
      v = {
        content: {
          'application/json': {
            examples: {
              example1: {
                value: { name: "test", id: 1 },
              },
            },
          },
        },
      }
      result = helper.send(:get_response_examples, v)
      expect(result).not_to be_empty
      expect(result.join).to include("name")
    end

    it "handles v3.0 content -> examples (string value)" do
      v = {
        content: {
          'application/json': {
            examples: {
              example1: {
                value: "simple string response",
              },
            },
          },
        },
      }
      result = helper.send(:get_response_examples, v)
      expect(result).to eq(["simple string response"])
    end

    it "handles v3.0 content -> examples (array value)" do
      v = {
        content: {
          'application/json': {
            examples: {
              example1: {
                value: [{ id: 1 }, { id: 2 }],
              },
            },
          },
        },
      }
      result = helper.send(:get_response_examples, v)
      expect(result.first).to eq("[")
      expect(result.last).to eq("]")
    end

    it "handles v3.0 content -> examples without :value key (returns empty string)" do
      v = {
        content: {
          'application/json': {
            examples: {
              example1: { summary: "just a summary" },
            },
          },
        },
      }
      result = helper.send(:get_response_examples, v)
      expect(result).to eq([""])
    end

    it "handles schema with allOf" do
      v = {
        schema: {
          allOf: [
            { properties: { name: { type: "string" } } },
            { properties: { id: { type: "integer" } } },
          ],
        },
      }
      result = helper.send(:get_response_examples, v)
      expect(result).not_to be_empty
      expect(result.join).to include("name:")
      expect(result.join).to include("id:")
    end

    it "handles schema with items.properties (array response)" do
      v = {
        schema: {
          type: "array",
          items: {
            properties: {
              name: { type: "string" },
            },
          },
        },
      }
      result = helper.send(:get_response_examples, v)
      expect(result).not_to be_empty
      expect(result.first).to eq("[")
      expect(result.last).to eq("]")
      expect(result.join).to include("name:")
    end

    it "handles schema with items.allOf (array of allOf)" do
      v = {
        schema: {
          type: "array",
          items: {
            allOf: [
              { properties: { name: { type: "string" } } },
              { properties: { age: { type: "integer" } } },
            ],
          },
        },
      }
      result = helper.send(:get_response_examples, v)
      expect(result).not_to be_empty
      expect(result.first).to eq("[")
      expect(result.join).to include("name:")
      expect(result.join).to include("age:")
    end

    it "handles schema with items having only type (no properties)" do
      v = {
        schema: {
          type: "array",
          items: { type: "string" },
        },
      }
      result = helper.send(:get_response_examples, v)
      expect(result).to eq(["[\"string\"]"])
    end

    it "handles @type key replacement" do
      v = {
        schema: {
          properties: {
            '@type': { type: "string", example: "Person" },
          },
        },
      }
      result = helper.send(:get_response_examples, v)
      joined = result.join
      expect(joined).to include("@type")
    end

    it "returns empty array when no schema or examples" do
      v = { description: "No content" }
      result = helper.send(:get_response_examples, v)
      expect(result).to be_empty
    end

    it "does not mutate the input hash" do
      v = {
        schema: { properties: { name: { type: "string" } } },
      }
      original = v.dup
      helper.send(:get_response_examples, v)
      expect(v.keys).to eq(original.keys)
    end

    it "handles remove_readonly=true by excluding readOnly fields" do
      v = {
        schema: {
          properties: {
            id: { type: "integer", readOnly: true },
            name: { type: "string" },
          },
        },
      }
      result = helper.send(:get_response_examples, v, true)
      expect(result.join).not_to include("id:")
      expect(result.join).to include("name:")
    end
  end

  describe "#get_patterns" do
    it "extracts regex patterns" do
      result = helper.send(:get_patterns, "email", { pattern: "^[a-z]+@[a-z]+$" })
      expect(result).not_to be_empty
      expect(result.first).to include("email")
      expect(result.first).to include("/")
    end

    it "extracts minLength/maxLength patterns" do
      result = helper.send(:get_patterns, "name", { minLength: 1, maxLength: 50 })
      expect(result.first).to include("1-50")
      expect(result.first).to include("LN$")
    end

    it "extracts minLength only" do
      result = helper.send(:get_patterns, "name", { minLength: 3 })
      expect(result.first).to include("3")
      expect(result.first).to include("LN$")
    end

    it "extracts maxLength only" do
      result = helper.send(:get_patterns, "name", { maxLength: 100 })
      expect(result.first).to include("0-100")
      expect(result.first).to include("LN$")
    end

    it "extracts minimum/maximum range patterns for integers" do
      result = helper.send(:get_patterns, "age", { type: "integer", minimum: 0, maximum: 150 })
      expect(result.first).to include("0..150")
    end

    it "extracts minimum/maximum for string type (produces LN pattern)" do
      result = helper.send(:get_patterns, "code", { type: "string", minimum: 1, maximum: 10 })
      expect(result.first).to include("1-10")
      expect(result.first).to include("LN$")
    end

    it "extracts minimum only (infinite range)" do
      result = helper.send(:get_patterns, "age", { type: "integer", minimum: 18 })
      expect(result.first).to include("18..")
    end

    it "extracts maximum only" do
      result = helper.send(:get_patterns, "count", { type: "integer", maximum: 100 })
      expect(result.first).to include("0..100")
    end

    it "extracts enum patterns" do
      result = helper.send(:get_patterns, "status", { enum: ["active", "inactive"] })
      expect(result.first).to include("active|inactive")
    end

    it "extracts boolean patterns" do
      result = helper.send(:get_patterns, "flag", { type: "boolean" })
      expect(result.first).to include("Boolean")
    end

    it "extracts datetime patterns" do
      result = helper.send(:get_patterns, "created", { format: "date-time" })
      expect(result.first).to include("DateTime")
    end

    it "handles \\x to \\u conversion in patterns" do
      result = helper.send(:get_patterns, "name", { pattern: "^[\\x41-\\x5A]+$" })
      expect(result).not_to be_empty
    end

    it "handles \\x to \\u00 conversion for hex ranges" do
      result = helper.send(:get_patterns, "name", { pattern: "^[\\xDF-\\xFF]+$" })
      expect(result).not_to be_empty
      expect(result.first).to include("\\u00")
    end

    it "handles pattern with escaped forward slashes" do
      result = helper.send(:get_patterns, "path", { pattern: "^[^\\.\\\\/:*?\"<>|]+$" })
      expect(result).not_to be_empty
    end

    it "handles array type with items.enum" do
      dpv = { type: "array", items: { type: "string", enum: ["a", "b", "c"] } }
      result = helper.send(:get_patterns, "tags", dpv)
      expect(result.first).to include("a|b|c")
    end

    it "handles array type with items.properties (nested patterns)" do
      dpv = {
        type: "array",
        items: {
          properties: {
            status: { enum: ["on", "off"] },
          },
        },
      }
      result = helper.send(:get_patterns, "items", dpv)
      expect(result).not_to be_empty
      expect(result.first).to include("items.status")
    end

    it "handles array with items.type only (no enum, no properties)" do
      dpv = { type: "array", items: { type: "boolean" } }
      result = helper.send(:get_patterns, "flags", dpv)
      expect(result).not_to be_empty
    end

    it "handles object type with nested properties" do
      dpv = {
        type: "object",
        properties: {
          city: { minLength: 1, maxLength: 100 },
        },
      }
      result = helper.send(:get_patterns, "address", dpv)
      expect(result).not_to be_empty
      expect(result.first).to include("address.city")
    end

    it "handles object type with empty root key" do
      dpv = {
        type: "object",
        properties: {
          city: { enum: ["NYC", "LA"] },
        },
      }
      result = helper.send(:get_patterns, "", dpv)
      expect(result).not_to be_empty
      expect(result.first).to include("'city'")
    end

    it "handles nullable type arrays (OAS 3.1)" do
      result = helper.send(:get_patterns, "flag", { type: ["boolean", "null"] })
      expect(result.first).to include("Boolean")
    end

    it "returns empty array when no patterns match" do
      result = helper.send(:get_patterns, "name", { type: "string" })
      expect(result).to be_empty
    end

    it "deduplicates patterns" do
      dpv = { type: "boolean" }
      result = helper.send(:get_patterns, "flag", dpv)
      expect(result.size).to eq(result.uniq.size)
    end
  end

  describe "#get_required_data" do
    it "extracts required field names" do
      body = { required: ["name", "email"], properties: {} }
      result = helper.send(:get_required_data, body)
      expect(result).to include(:name)
      expect(result).to include(:email)
    end

    it "extracts required fields from allOf" do
      body = {
        allOf: [
          { required: ["id"], properties: {} },
          { required: ["name"], properties: {} },
        ],
        properties: {},
      }
      result = helper.send(:get_required_data, body)
      expect(result).to include(:id)
      expect(result).to include(:name)
    end

    it "returns empty array when no required fields" do
      body = { properties: { name: { type: "string" } } }
      result = helper.send(:get_required_data, body)
      expect(result).to be_empty
    end

    it "handles nested required fields" do
      body = {
        required: ["address"],
        properties: {
          address: {
            type: "object",
            required: ["city"],
            properties: {
              city: { type: "string" },
            },
          },
        },
      }
      result = helper.send(:get_required_data, body)
      expect(result).to include(:address)
      expect(result).to include(:"address.city")
    end

    it "handles empty required array" do
      body = { required: [], properties: {} }
      result = helper.send(:get_required_data, body)
      expect(result).to be_empty
    end

    it "handles allOf items without required key" do
      body = {
        allOf: [
          { properties: { name: { type: "string" } } },
        ],
        properties: {},
      }
      result = helper.send(:get_required_data, body)
      expect(result).to be_empty
    end

    it "handles body without properties key" do
      body = { required: ["name"] }
      result = helper.send(:get_required_data, body)
      expect(result).to eq([:name])
    end
  end

  describe "#filter" do
    it "filters hash by specified keys" do
      hash = { name: "John", age: 30, email: "john@example.com" }
      result = helper.send(:filter, hash, [:name, :email])
      expect(result).to eq({ name: "John", email: "john@example.com" })
    end

    it "returns empty hash for missing keys" do
      hash = { name: "John" }
      result = helper.send(:filter, hash, [:missing])
      expect(result).to be_empty
    end

    it "returns empty hash values for hash-type values" do
      hash = { address: { city: "NYC" } }
      result = helper.send(:filter, hash, [:address])
      expect(result).to eq({ address: {} })
    end

    it "accepts a single symbol key (auto-wraps in array)" do
      hash = { name: "John", age: 30 }
      result = helper.send(:filter, hash, :name)
      expect(result).to eq({ name: "John" })
    end

    it "delegates to nice_filter when nested=true" do
      hash = { name: "John", age: 30 }
      result = helper.send(:filter, hash, [:name], true)
      expect(result).to eq({ name: "John" })
    end

    it "handles dot-notation symbol keys for nested access" do
      hash = { address: { city: "NYC", zip: "10001" } }
      result = helper.send(:filter, hash, [:"address.city"])
      expect(result).to have_key(:address)
      expect(result[:address]).to have_key(:city)
    end
  end

  describe "#pretty_hash_symbolized" do
    it "formats a flat hash" do
      hash = { name: "John", age: 30 }
      result = helper.send(:pretty_hash_symbolized, hash)
      expect(result.join("\n")).to include("name:")
      expect(result.join("\n")).to include("age:")
    end

    it "handles nested hashes" do
      hash = { address: { city: "NYC" } }
      result = helper.send(:pretty_hash_symbolized, hash)
      joined = result.join("\n")
      expect(joined).to include("address:")
      expect(joined).to include("city:")
    end

    it "handles empty hash" do
      result = helper.send(:pretty_hash_symbolized, {})
      expect(result).to eq(["{", "},"])
    end

    it "handles deeply nested hashes" do
      hash = { a: { b: { c: "deep" } } }
      result = helper.send(:pretty_hash_symbolized, hash)
      joined = result.join("\n")
      expect(joined).to include("a:")
      expect(joined).to include("b:")
      expect(joined).to include("c:")
    end

    it "handles nil values" do
      hash = { key: nil }
      result = helper.send(:pretty_hash_symbolized, hash)
      expect(result.join("\n")).to include("nil")
    end

    it "handles array values" do
      hash = { items: [1, 2, 3] }
      result = helper.send(:pretty_hash_symbolized, hash)
      expect(result.join("\n")).to include("items:")
    end

    it "handles symbol values" do
      hash = { status: :active }
      result = helper.send(:pretty_hash_symbolized, hash)
      expect(result.join("\n")).to include(":active")
    end
  end

  describe "#get_data_all_of_bodies" do
    it "flattens allOf schemas" do
      param = {
        schema: {
          allOf: [
            { properties: { name: { type: "string" } } },
            { properties: { age: { type: "integer" } } },
          ],
        },
      }
      data_examples_all_of, bodies = helper.send(:get_data_all_of_bodies, param)
      expect(bodies.size).to eq 2
    end

    it "handles non-allOf schemas" do
      param = {
        schema: {
          properties: { name: { type: "string" } },
        },
      }
      _data_examples_all_of, bodies = helper.send(:get_data_all_of_bodies, param)
      expect(bodies.size).to eq 1
    end

    it "handles array input (recursive case)" do
      arr = [
        { properties: { name: { type: "string" } } },
        { properties: { age: { type: "integer" } } },
      ]
      _data_examples_all_of, bodies = helper.send(:get_data_all_of_bodies, arr)
      expect(bodies.size).to eq 2
    end

    it "handles nested allOf within allOf" do
      param = {
        schema: {
          allOf: [
            {
              allOf: [
                { properties: { inner1: { type: "string" } } },
                { properties: { inner2: { type: "integer" } } },
              ],
            },
            { properties: { outer: { type: "boolean" } } },
          ],
        },
      }
      data_examples_all_of, bodies = helper.send(:get_data_all_of_bodies, param)
      expect(data_examples_all_of).to eq true
      expect(bodies.size).to eq 3
    end

    it "handles mixed items with and without allOf" do
      param = {
        schema: {
          allOf: [
            { properties: { simple: { type: "string" } } },
            {
              allOf: [
                { properties: { nested: { type: "integer" } } },
              ],
            },
          ],
        },
      }
      data_examples_all_of, bodies = helper.send(:get_data_all_of_bodies, param)
      expect(data_examples_all_of).to eq true
      expect(bodies.size).to eq 2
    end
  end

  describe "#build_example_value (via OpenApiImport)" do
    it "returns example value directly" do
      result = OpenApiImport.send(:build_example_value, { example: "hello" })
      expect(result).to eq("hello")
    end

    it "returns first from examples (plural)" do
      result = OpenApiImport.send(:build_example_value, { examples: ["a", "b"] })
      expect(result).to eq("a")
    end

    it "returns 'string' for string type" do
      result = OpenApiImport.send(:build_example_value, { type: "string" })
      expect(result).to eq("string")
    end

    it "returns format for string type with format" do
      result = OpenApiImport.send(:build_example_value, { type: "string", format: "email" })
      expect(result).to eq("email")
    end

    it "returns 0 for integer type" do
      result = OpenApiImport.send(:build_example_value, { type: "integer" })
      expect(result).to eq(0)
    end

    it "returns 0.0 for number type with float format" do
      result = OpenApiImport.send(:build_example_value, { type: "number", format: "float" })
      expect(result).to eq(0.0)
    end

    it "returns 0 for number type without float format" do
      result = OpenApiImport.send(:build_example_value, { type: "number" })
      expect(result).to eq(0)
    end

    it "returns true for boolean type" do
      result = OpenApiImport.send(:build_example_value, { type: "boolean" })
      expect(result).to eq(true)
    end

    it "returns empty hash for object type without properties" do
      result = OpenApiImport.send(:build_example_value, { type: "object" })
      expect(result).to eq({})
    end

    it "returns populated hash for object type with properties" do
      result = OpenApiImport.send(:build_example_value, {
        type: "object",
        properties: { name: { type: "string" }, age: { type: "integer" } },
      })
      expect(result).to eq({ name: "string", age: 0 })
    end

    it "returns empty array for array type" do
      result = OpenApiImport.send(:build_example_value, { type: "array" })
      expect(result).to eq([])
    end

    it "handles nullable type arrays (OAS 3.1)" do
      result = OpenApiImport.send(:build_example_value, { type: ["string", "null"] })
      expect(result).to eq("string")
    end

    it "returns empty string when no type" do
      result = OpenApiImport.send(:build_example_value, {})
      expect(result).to eq("")
    end
  end
end
