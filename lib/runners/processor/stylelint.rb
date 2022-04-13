module Runners
  class Processor::Stylelint < Processor
    include Nodejs

    SCHEMA = _ = StrongJSON.new do
      extend Schema::ConfigTypes

      # @type self: SchemaClass
      let :config, npm(
        config: string?,
        syntax: string?,
        'ignore-path': string?,
        'ignore-disables': boolean?,
        'report-needless-disables': boolean?,
        quiet: boolean?,
        target: target,
        glob: target, # alias for `target`
      )

      let :issue, object(
        severity: string?,
      )
    end

    register_config_schema SCHEMA.config

    CONSTRAINTS = {
      "stylelint" => Gem::Requirement.new(">= 8.3.0", "< 15.0.0").freeze,
    }.freeze

    DEFAULT_TARGET_FILES = "*.{css,less,sass,scss,sss}".freeze
    DEFAULT_TARGET = "**/#{DEFAULT_TARGET_FILES}".freeze
    DEFAULT_CONFIG_FILE = (Pathname(Dir.home) / 'sider_recommended_config.yaml').to_path.freeze
    DEFAULT_CONFIG_FILE_OLD = (Pathname(Dir.home) / 'sider_recommended_config.old.yaml').to_path.freeze
    DEFAULT_IGNORE_FILE = (Pathname(Dir.home) / 'sider_recommended_stylelintignore').to_path.freeze

    def self.config_example
      <<~'YAML'
        root_dir: project/
        dependencies:
          - my-stylelint-plugin@2
        npm_install: false
        config: config/.stylelintrc.yml
        syntax: scss
        ignore-path: config/.stylelintignore
        ignore-disables: true
        report-needless-disables: true
        quiet: true
        target: ["app/**/*.scss"]
      YAML
    end

    def setup
      prepare_ignore_file

      begin
        install_nodejs_deps constraints: CONSTRAINTS
      rescue UserError => exn
        return Results::Failure.new(guid: guid, message: exn.message, analyzer: nil)
      end

      # Must do after installation
      prepare_config_file

      yield
    end

    def analyze(changes)
      delete_unchanged_files(changes, only: [DEFAULT_TARGET_FILES])

      default_options = ['--formatter=json', '--no-color']

      # stylelint v10.0.0 throws an error if glob matches no files.
      # @see https://github.com/stylelint/stylelint/releases/tag/10.0.0
      # This behavior is inconvenient when deleting unchanged files
      #
      # ---
      #
      # The `--allow-empty-input` option breaks with v10.0.0. Fixed with v10.0.1.
      # @see https://github.com/stylelint/stylelint/releases/tag/10.0.1
      # @see https://github.com/stylelint/stylelint/pull/4029
      if Gem::Version.new(analyzer_version) >= Gem::Version.new("10.0.1")
        default_options << '--allow-empty-input'
      end

      stdout, stderr, status = capture3(
        nodejs_analyzer_bin,
        *default_options,
        *stylelint_config,
        *syntax,
        *ignore_path,
        *ignore_disables,
        *report_needless_disables,
        *quiet,
        *glob,
      )

      # https://github.com/stylelint/stylelint/blob/master/docs/user-guide/cli.md#exit-codes
      # 0 => No Issues
      # 2 => Issues exist
      # Others => Something wrong, target files don't exist, ...
      unless [0, 2].include?(status.exitstatus)
        return Results::Failure.new(guid: guid, message: [stdout, stderr].join("\n"), analyzer: analyzer)
      end

      Results::Success.new(guid: guid, analyzer: analyzer, issues: parse_result(stdout)).tap do |result|
        @warning_set&.sort&.each do |warning|
          add_warning(warning, file: config_file_path&.to_path)
        end
      end
    end

    private

    def glob
      Array(config_linter[:target] || config_linter[:glob] || DEFAULT_TARGET)
    end

    def stylelint_config
      config = config_linter[:config]
      config ? ["--config=#{config}"] : []
    end

    def syntax
      syntax = config_linter[:syntax]
      syntax ? ["--syntax=#{syntax}"] : []
    end

    def ignore_path
      path = config_linter[:'ignore-path']
      path ? ["--ignore-path=#{path}"] : []
    end

    def ignore_disables
      config_linter[:'ignore-disables'] ? ["--ignore-disables"] : []
    end

    def report_needless_disables
      rd = config_linter[:'report-needless-disables']
      rd ? ["--report-needless-disables"] : []
    end

    def quiet
      config_linter[:quiet] ? ["--quiet"] : []
    end

    def parse_result(stdout)
      JSON.parse(stdout, symbolize_names: true).flat_map do |file|
        check_warning(file[:deprecations])
        path = relative_path(file[:source])

        file[:warnings].map do |warning|
          line = warning[:line]
          id = warning[:rule]

          Issue.new(
            path: path,
            location: line ? Location.new(start_line: line, start_column: warning[:column]) : nil, # NOTE: There is a rare case that stylelint doesn't output the `line`.
            id: id,
            message: normalize_message(id, warning[:text]),
            links: Array(rule_doc_urls[id]),
            object: {
              severity: warning[:severity],
            },
            schema: SCHEMA.issue,
          )
        end
      end
    end

    # @see https://github.com/stylelint/stylelint/blob/11.1.1/lib/formatters/stringFormatter.js#L120
    def normalize_message(id, message)
      message.delete_suffix("(#{id})").strip # trim ID
    end

    # @see https://github.com/stylelint/stylelint/blob/11.1.1/lib/formatters/stringFormatter.js#L120
    def rule_doc_urls
      @rule_doc_urls ||=
        begin
          # Find stylelint installed location.
          stdout, _, status = capture3 "node", "-pe", "require.resolve('stylelint')"
          if status.success?
            Pathname.glob(stdout.chomp.sub("/lib/index.js", "/lib/rules/*"))
              .filter(&:directory?)
              .each_with_object({}) do |dir, hash|
                rule = dir.basename.to_s
                hash[rule] = "#{analyzer_github}/tree/#{analyzer_version}/lib/rules/#{rule}"
              end
          else
            {}
          end
        end
    end

    def prepare_config_file
      return if config_file_path

      # NOTE: `stylelint-config-recommended@2` does not work with `stylelint@11`.
      src = if Gem::Version.new(analyzer_version) >= Gem::Version.new("11.0.0")
              DEFAULT_CONFIG_FILE
            else
              DEFAULT_CONFIG_FILE_OLD
            end

      FileUtils.copy_file(src, '.stylelintrc.yaml')
    end

    def prepare_ignore_file
      ignore_file = '.stylelintignore'
      unless File.exist? ignore_file
        FileUtils.copy_file(DEFAULT_IGNORE_FILE, ignore_file)
      end
    end

    # returns available config file path. If the file doesn't exist, it returns nil.
    def config_file_path
      config_path = config_linter[:config]
      if config_path
        current_dir / config_path
      elsif package_json_path.exist? && package_json.key?(:stylelint)
        package_json_path
      else
        # @see https://github.com/stylelint/stylelint/blob/master/docs/user-guide/configuration.md
        candidates = %w[
          .stylelintrc
          .stylelintrc.js
          .stylelintrc.json
          .stylelintrc.yaml
          .stylelintrc.yml
          stylelint.config.js
        ]
        candidates.find { |filename| File.exist?(filename) }&.then { |filename| current_dir / filename }
      end
    end

    # Save warnings written by stylelint.
    # stylelint writes "deprecations" flags in each file, so we cannot conduct naive implementations.
    # Without this method, if we write a warning when the "deprecations" appear,
    # the same number of duplicated warnings as files will appear.
    # We use `Set` to avoid it.
    def check_warning(deprecations)
      @warning_set ||= Set.new
      deprecations.each do |dep|
        @warning_set << "#{dep[:text]} #{dep[:reference]}"
      end
    end
  end
end
