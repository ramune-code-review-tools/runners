module Runners
  module Java
    class InvalidDependency < UserError; end

    def self.included(klass)
      # @type var klass: singleton(Processor)
      Config.register_warnings do |config|
        config.add_warning_for_deprecated_option(analyzer: klass.analyzer_id, old: :jvm_deps, new: :dependencies)
      end
    end

    def show_runtime_versions
      capture3! "java", "-version"
      capture3! "gradle", "--version"
      super
    end

    def analyzer_version
      @analyzer_version || default_analyzer_version
    end

    def install_jvm_deps(to: Pathname(Dir.home).join("dependencies"))
      return if config_jvm_deps.empty?

      chdir to do
        generate_jvm_deps_file

        trace_writer.message "Install dependencies..." do
          fetch_deps_via_gradle!
          deps = config_jvm_deps.map { |dep| "* #{dep}" }
          trace_writer.message <<~MSG
            Successfully installed #{deps.size} #{deps.size == 1 ? 'dependency' : 'dependencies'}:
            #{deps.join("\n")}
          MSG

          @analyzer_version = extract_version!(analyzer_bin)
        end
      end
    end

    def pmd_help
      # NOTE: Both PMD and CPD support the `-h` option.
      stdout, _ = capture3! analyzer_bin, "-h", trace_stdout: false, is_success: ->(status) { [0, 1].include?(status.exitstatus) }
      stdout
    end

    # NOTE: PMD does not provide a CLI option to show its version.
    def pmd_version
      help = pmd_help
      version = help.match(%r{pmd-bin-(?<version>[\d.]+)/bin/}) { |m| m[:version] }
      if version
        trace_writer.message "PMD version: #{version}"
        version
      else
        raise "Could not find a PMD version:\n#{help}"
      end
    end

    private

    def fetch_deps_via_gradle!
      capture3! "gradle", "--no-build-cache", "--parallel", "--quiet", "deps"
    end

    def config_jvm_deps
      return config_jvm_deps_old unless config_linter[:dependencies]

      @config_jvm_deps ||= Array(config_linter[:dependencies]).map do |dep|
        # @type var dep: Hash[Symbol, String] | String
        case dep
        when Hash
          dep.values.join(":")
        else
          dep
        end
      end
    end

    def config_jvm_deps_old
      @config_jvm_deps_old ||= Array(config_linter[:jvm_deps]).map do |dep|
        # @type var dep: Array[String]
        group, name, version = dep
        unless group && name && version
          message = <<~MSG
            An invalid dependency is found in your `#{config.path_name}`: `#{dep.inspect}`
            Dependencies should be of the form: `[group, name, version]`
          MSG
          trace_writer.error message
          raise InvalidDependency, message
        end

        dep.join(":")
      end
    end

    def generate_jvm_deps_file
      filename = "build.gradle"

      # @see https://docs.gradle.org/current/userguide/declaring_repositories.html
      # @see https://blog.gradle.org/jcenter-shutdown
      repos = ["mavenCentral()", "google()"].map { |repo| "  #{repo}" }.join("\n")

      trace_writer.message "Generating #{filename}..." do
        deps = config_jvm_deps.map { |dep| "  implementation '#{dep}'" }.join("\n")
        content = <<~GRADLE
          plugins {
            id 'java'
          }
          repositories {
          #{repos}
          }
          dependencies {
          #{deps}
          }
          task deps(type: Copy) {
            from configurations.compileClasspath
            into '.'
          }
        GRADLE

        File.write filename, content
        trace_writer.message <<~MSG
          ---
          #{content.chomp}
          ---
        MSG
      end
    end
  end
end
