require "optparse"

module NodeHarness
  class CLI
    # @dynamic stdout, stderr, guid, analyzer, base, base_key, head, head_key, ssh_key, working_dir
    attr_reader :stdout
    attr_reader :stderr
    attr_reader :guid
    attr_reader :analyzer
    attr_reader :base
    attr_reader :base_key
    attr_reader :head
    attr_reader :head_key
    attr_reader :ssh_key
    attr_reader :working_dir

    def initialize(argv:, stdout:, stderr:)
      @stdout = stdout
      @stderr = stderr

      @analyzer = nil
      @encryption_key = nil

      OptionParser.new do |opts|
        opts.on("--analyzer=ANALYZER") do |analyzer|
          @analyzer = analyzer
        end
        opts.on("--base=BASE") do |base|
          @base = base
        end
        opts.on("--base-key=BASE_KEY") do |base_key|
          @base_key = base_key
        end
        opts.on("--head=HEAD") do |head|
          @head = head
        end
        opts.on("--head-key=HEAD_KEY") do |head_key|
          @head_key = head_key
        end
        opts.on("--ssh-key=SSH_KEY") do |ssh_key|
          @ssh_key = ssh_key
        end
        opts.on("--working=WORKING") do |working|
          @working_dir = working
        end
      end.parse!(argv)

      @guid = _ = argv.shift
    end

    def with_working_dir
      if (w = working_dir)
        path = Pathname(w)
        path.mkpath
        yield path
      else
        Dir.mktmpdir do |dir|
          yield Pathname(dir)
        end
      end
    end

    def validate_options!
      case
      when base && head
        # ok
      when !base && head
        # ok
      else
        raise "--head is required while --base is optional (base=#{base}, head=#{head})"
      end

      raise "base_key is given but base is missing" if !base && base_key
      raise "head_key is given but head is missing" if !head && head_key
      validate_analyzer!
      self
    end

    def validate_analyzer!
      raise "--analyzer is required" unless analyzer
      raise "The specified analyzer is not supported" unless processor_class
    end

    def processor_class
      # TODO: Add more runners
      @processor_class ||= {
        rubocop: NodeHarness::Runners::Rubocop::Processor,
        rails_best_practices: NodeHarness::Runners::RailsBestPractices::Processor,
        reek: NodeHarness::Runners::Reek::Processor,
        goodcheck: NodeHarness::Runners::Goodcheck::Processor,
        querly: NodeHarness::Runners::Querly::Processor,
        brakeman: NodeHarness::Runners::Brakeman::Processor,
        haml_lint: NodeHarness::Runners::HamlLint::Processor,
        scss_lint: NodeHarness::Runners::ScssLint::Processor,
        code_sniffer: NodeHarness::Runners::CodeSniffer::Processor,
        phpmd: NodeHarness::Runners::Phpmd::Processor,
        phinder: NodeHarness::Runners::Phinder::Processor,
        checkstyle: NodeHarness::Runners::Checkstyle::Processor,
        pmd_java: NodeHarness::Runners::PmdJava::Processor,
        javasee: NodeHarness::Runners::Javasee::Processor,
        eslint: NodeHarness::Runners::Eslint::Processor,
        coffeelint: NodeHarness::Runners::Coffeelint::Processor,
        jshint: NodeHarness::Runners::Jshint::Processor,
        stylelint: NodeHarness::Runners::Stylelint::Processor,
        tslint: NodeHarness::Runners::Tslint::Processor,
        tyscan: NodeHarness::Runners::Tyscan::Processor,
        flake8: NodeHarness::Runners::Flake8::Processor,
        misspell: NodeHarness::Runners::Misspell::Processor,
        go_vet: NodeHarness::Runners::GoVet::Processor,
        golint: NodeHarness::Runners::Golint::Processor,
        gometalinter: NodeHarness::Runners::Gometalinter::Processor,
        swiftlint: NodeHarness::Runners::Swiftlint::Processor,
      }[analyzer.to_sym]
    end

    def run
      with_working_dir do |working_dir|
        writer = JSONSEQ::Writer.new(io: stdout)
        trace_writer = TraceWriter.new(writer: writer)

        Workspace.open(base: base, base_key: base_key, head: head, head_key: head_key, ssh_key: ssh_key, working_dir: working_dir, trace_writer: trace_writer) do |workspace|
          harness = Harness.new(guid: guid, processor_class: processor_class, workspace: workspace, trace_writer: trace_writer)

          result = harness.run
          warnings = harness.warnings
          ci_config = harness.ci_config
          json = {
            result: result.as_json,
            "harness-version": VERSION,
            warnings: warnings,
            ci_config: ci_config,
          }

          trace_writer.message "Writing result..." do
            writer << Schema::Result.envelope.coerce(json)
          end
        end
      end
    end
  end
end
