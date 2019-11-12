module Runners
  class Processor::CodeSniffer < Processor
    Schema = StrongJSON.new do
      let :runner_config, Schema::RunnerConfig.base.update_fields { |fields|
        fields.merge!({
                        version: enum?(string, numeric),
                        dir: string?,
                        standard: string?,
                        extensions: string?,
                        encoding: string?,
                        ignore: string?,
                        # DO NOT ADD ANY OPTION under `options`.
                        options: optional(object(
                                            dir: string?,
                                            standard: string?,
                                            extensions: string?,
                                            encoding: string?,
                                            ignore: string?
                                          ))
                      })
      }
    end

    def self.ci_config_section_name
      "code_sniffer"
    end

    def setup
      add_warning_if_deprecated_options([:options], doc: "https://help.sider.review/tools/php/codesniffer")
      yield
    end

    def analyze(changes)
      ensure_runner_config_schema(Schema.runner_config) do |config|
        check_runner_config(config) do |options, target|
          run_analyzer(options, target)
        end
      end
    end

    private

    def check_runner_config(config)
      if config[:version].to_i == 2
        add_warning("Sider has no longer supported PHP_CodeSniffer v2. Sider executes v3 even if putting `2` as `version` option.", file: ci_config_path_name)
      end

      options = additional_options(config)
      target = directory(config)

      yield options, target
    end

    def analyzer_name
      "code_sniffer"
    end

    def analyzer_bin
      "phpcs"
    end

    def additional_options(config)
      # If a repository doesn't have `sideci.yml`, use default configuration with `default_sideci_options` method.
      if config.empty?
        default_sideci_options[:options].map do |k, v|
          "--#{k}=#{v}"
        end
      else
        standard = standard_option(config)
        extensions = extensions_option(config)
        encoding = encoding_option(config)
        ignore = ignore_option(config)

        [standard, extensions, encoding, ignore].compact
      end
    end

    def standard_option(config)
      standard = config[:standard] || config.dig(:options, :standard) || default_sideci_options.dig(:options, :standard)
      "--standard=#{standard}"
    end

    def extensions_option(config)
      extensions = config[:extensions] || config.dig(:options, :extensions) || default_sideci_options.dig(:options, :extensions)
      "--extensions=#{extensions}"
    end

    def encoding_option(config)
      encoding = config[:encoding] || config.dig(:options, :encoding)
      "--encoding=#{encoding}" if encoding
    end

    def ignore_option(config)
      ignore = config[:ignore] || config.dig(:options, :ignore)
      "--ignore=#{ignore}" if ignore
    end

    def directory(config)
      config[:dir] || config.dig(:options, :dir) || default_sideci_options[:dir]
    end

    def default_sideci_options
      @default_sideci_options ||=
        case php_framework
        when :CakePHP
          {
            options: {
              standard: 'CakePHP',
              extensions: 'php',
            },
            dir: 'app/',
          }
        when :Symfony
          {
            options: {
              standard: 'Symfony',
              extensions: 'php',
            },
            dir: 'src/',
          }
        else
          {
            options: {
              standard: 'PSR2',
              extensions: 'php',
            },
            dir: './',
          }
        end
    end

    def php_framework
      @php_framework ||= {
        CakePHP: 'lib/Cake/Core/CakePlugin.php',
        Symfony: 'app/SymfonyRequirements.php',
      }.find do |framework, file|
        break framework if (current_dir / file).exist?
      end
    end

    def print_large_string(str)
      max_size = 24_000
      if str.size <= max_size
        trace_writer.message str
      else
        # NOTE: To avoid stalling, it outputs prefix and suffix only.
        trace_writer.message str[0...(max_size / 2)]
        trace_writer.message '......'
        trace_writer.message str[(str.size - (max_size / 2))...str.size]
      end
    end

    def run_analyzer(options, target)
      output = working_dir + 'output.txt'
      # code_sniffer always exists with "statsu = 1" when any warnings exist, so we don't see the status code.
      #
      # Runtime erros such as "directory not found" will be displayed in stdout.
      #
      # Without `--report-json`, if users configure with `<arg name="report" value="summary"/>`,
      # all output is mixed in stdout. So, we have to write output to a file.
      capture3(
        analyzer_bin,
        '--report=json',
        "--report-json=#{output}",
        *options,
        target
      )

      stdout = output.read
      trace_writer.message "Result Output:"
      print_large_string(stdout)

      Results::Success.new(guid: guid, analyzer: analyzer).tap do |result|
        issues = []

        JSON.parse(stdout, symbolize_names: true)[:files].each do |path, suggests|
          suggests[:messages].each do |suggest|
            loc = Location.new(
              start_line: suggest[:line].to_i,
              start_column: nil,
              end_line: nil,
              end_column: nil
            )

            issues << Issue.new(
              path: relative_path(path.to_s),
              location: loc,
              id: suggest[:source],
              message: suggest[:message],
            )
          end
        end

        issues.uniq { |issue| [issue.path, issue.location, issue.id, issue.message] }.each do |issue|
          result.add_issue issue
        end
      end
    rescue JSON::ParserError => exn
      trace_writer.message exn.inspect.truncate(1000)
      Results::Failure.new(guid: guid,
                                        analyzer: analyzer,
                                        message: "code sniffer output parsing failed")
    end
  end
end
