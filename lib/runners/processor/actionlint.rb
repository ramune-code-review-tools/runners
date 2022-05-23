module Runners
  class Processor::Actionlint < Processor
    SCHEMA = _ = StrongJSON.new do
      extend Schema::ConfigTypes

      # @type self: SchemaClass
      let :config, base(
        target: target,

        # Native options
        ignore: one_or_more_strings?,
      )

      let :issue, object(
        shellcheck: object?(id: string, severity: string, line: integer, column: integer, message: string, url: string),
        pyflakes: object?(line: integer, column: integer, message: string),
      )
    end

    ALLOWED_ERRORS = [
      "no project was found in any parent directories of",
      "no YAML file was found in",
    ].freeze
    SHELLCHECK_MESSAGE_FORMAT = /shellcheck reported issue in this script: (?<id>SC[^:]+):(?<severity>\w+):(?<line>\d+):(?<column>\d+): (?<message>.*)$/.freeze
    PYFLAKES_MESSAGE_FORMAT = /pyflakes reported issue in this script: (?<line>\d+):(?<column>\d+) (?<message>.*)$/.freeze

    register_config_schema SCHEMA.config

    def self.config_example
      <<~'YAML'
        root_dir: project/
        target:
          - .github/workflows/one_workflow.yml
          - .github/workflows/another_workflow.yml
        ignore:
          - "job .* needs job"
          - "unknown Webhook event"
      YAML
    end

    # This analyser uses git metadata (.git/).
    def use_git_metadata_dir?
      true
    end

    def analyzer_options
      [
        "-format", "{{json .}}",

        # Specify error message patterns to ignore
        *(Array(config_linter[:ignore]).flat_map { |v| ["-ignore", v] }),

        # After -- separator, specify target files to analyze
        "--", *Array(config_linter[:target]),
      ]
    end

    def analyze(changes)
      stdout, stderr, status = capture3(analyzer_bin, *analyzer_options)
      exitstatus = status.exitstatus

      # @see https://github.com/rhysd/actionlint/blob/v1.6.3/docs/usage.md#exit-status
      case
      when exitstatus && [0, 1].include?(exitstatus)
        # Zero or more issue found => Success
        Results::Success.new(guid: guid, analyzer: analyzer, issues: parse_result(stdout))
      when ALLOWED_ERRORS.any? { |pattern| stderr.include?(pattern) }
        # No yaml files found => Success
        add_warning(stderr)
        Results::Success.new(guid: guid, analyzer: analyzer)
      else
        # Other outcomes (e.g. fatal errors) with exit code 2, 3 => Failure
        raise "#{analyzer_name} returned exit code #{exitstatus.inspect}. See logs for details."
      end
    end

    def parse_result(output)
      JSON.parse(output, symbolize_names: true).map do |issue|
        # NOTE: the actionlint JSON output contains a `issue[:snippet]` field as well,
        # however Sider has no use for it at the moment.
        message = issue.fetch(:message)
        shellcheck = find_shellcheck_issue(message)
        id = issue[:kind] + (shellcheck ? "/#{shellcheck[:id]}" : "")

        Issue.new(
          id: id,
          path: relative_path(issue[:filepath]),
          location: Location.new(start_line: issue[:line], start_column: issue[:column]),
          message: message,
          object: {
            shellcheck: shellcheck,
            pyflakes: find_pyflakes_issue(message),
          },
          schema: SCHEMA.issue,
          links: shellcheck ? [shellcheck[:url]] : []
        )
      end
    end

    def find_shellcheck_issue(message)
      # Parse shellcheck issue details from actionlint message.
      # actionlint message example:
      # "shellcheck reported issue in this script: SC2086:info:1:14: Double quote to prevent globbing and word splitting"
      message.match(SHELLCHECK_MESSAGE_FORMAT) do |m|
        issue = m.named_captures.transform_keys(&:to_sym)
        line = Integer(issue.fetch(:line).to_s)
        column = Integer(issue.fetch(:column).to_s)
        url = "#{analyzer_github(:shellcheck)}/wiki/#{issue.fetch(:id)}"
        { **issue, line: line, column: column, url: url }
      end
    end

    def find_pyflakes_issue(message)
      # Parse pyflakes issue details from actionlint message.
      # actionlint message example:
      # "pyflakes reported issue in this script: 1:7 undefined name 'hello'"
      message.match(PYFLAKES_MESSAGE_FORMAT) do |m|
        issue = m.named_captures.transform_keys(&:to_sym)
        line = Integer(issue.fetch(:line).to_s)
        column = Integer(issue.fetch(:column).to_s)
        { **issue, line: line, column: column }
      end
    end
  end
end
