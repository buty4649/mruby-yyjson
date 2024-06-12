# mruby-yyjson

[yyjson](https://github.com/ibireme/yyjson) binding for mruby.

## Installation

Add conf.gem line to `build_config.rb`:

```ruby
MRuby::Build.new do |conf|
-- snip --

  conf.gem File.expand_path(__dir__)
end
```

## Implemented Method

| Method                | mruby-yyjson | Memo               |
|-----------------------|--------------|--------------------|
| JSON.[]               |              |                    |
| JSON.create_id        |              |                    |
| JSON.create_id=       |              |                    |
| JSON.generator        |              |                    |
| JSON.parser           |              |                    |
| JSON.state            |              |                    |
| JSON.#dump            |              |                    |
| JSON.#fast_generate   |              |                    |
| JSON.#fast_unparse    |              | obsolete           |
| JSON.#generate        | ✓            |                    |
| JSON.#unparse         |              | obsolete           |
| JSON.#load            | ✓            |                    |
| JSON.#load_file       | ✓            | require `mruby-io` |
| JSON.#load_file!      |              |                    |
| JSON.#restore         |              |                    |
| JSON.#parse           | ✓            |                    |
| JSON.#parse!          |              |                    |
| JSON.#pretty_generate | ✓            |                    |
| JSON.#pretty_unparse  |              | obsolete           |
||||
| Object#to_json       | ✓            |                     |

## License

mrb-yyjson is licensed under the MIT License.

This project includes code from the yyjson library, specifically [yyjson.c](src/yyjson.c) and [yyjson.h](src/yyjson.h), which are licensed under the MIT License. A copy of the MIT License can be found in the [LICENSE](./LICENSE) file in the root of this repository.
