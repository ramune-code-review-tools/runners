require_relative 'test_helper'

class RubyTest < Minitest::Test
  include TestHelper

  GemInstaller = NodeHarness::Ruby::GemInstaller
  LockfileLoader = NodeHarness::Ruby::LockfileLoader

  def trace_writer
    @trace_writer ||= NodeHarness::TraceWriter.new(writer: [])
  end

  def shell
    @shell ||= NodeHarness::Shell.new(
      current_dir: __dir__,
      env_hash: {},
      trace_writer: trace_writer
    )
  end

  def test_gemfile_content
    specs = [
      GemInstaller::Spec.new(name: "strong_json", version: ["0.4.0"]),
      GemInstaller::Spec.new(name: "rubocop", version: [], source: GemInstaller::GitSource.new(repo: "https://github.com/rubocop-hq/rubocop.git")),
      GemInstaller::Spec.new(name: "node_harness", version: [], source:  GemInstaller::GitSource.new(repo: "git@github.com:sider/node_harness.git", ref: "e66806c02849a0d0bdea66be88b5967d5eb3305d")),
      GemInstaller::Spec.new(name: "rubocop-rails", version: [], source: GemInstaller::GitSource.new(repo: "https://github.com/rubocop-hq/rubocop-rails.git", branch: "dev")),
      GemInstaller::Spec.new(name: "rubocop-rspec", version: [], source: GemInstaller::GitSource.new(repo: "https://github.com/rubocop-hq/rubocop-rspec.git", tag: "v1.13.0")),
      GemInstaller::Spec.new(name: "rubocop-sider", version: [], source: GemInstaller::RubygemsSource.new("https://gems.sider.review")),
    ]

    mktmpdir do |path|
      installer = GemInstaller.new(
        shell: shell,
        specs: specs,
        home: path,
        ci_config_path_name: "sider.yml",
        constraints: { "strong_json" => ["<= 0.8"], "rubocop" => [">= 0.55.0"] },
        trace_writer: trace_writer
      )

      assert_equal [
                     'source "https://rubygems.org"',
                     'source "https://rubygems.org" do',
                     '  gem("strong_json", "0.4.0", "<= 0.8")',
                     'end',
                     'git "https://github.com/rubocop-hq/rubocop.git", ref: nil, branch: nil, tag: nil do',
                     '  gem("rubocop", ">= 0.55.0")',
                     'end',
                     'git "git@github.com:sider/node_harness.git", ref: "e66806c02849a0d0bdea66be88b5967d5eb3305d", branch: nil, tag: nil do',
                     '  gem("node_harness", )',
                     'end',
                     'git "https://github.com/rubocop-hq/rubocop-rails.git", ref: nil, branch: "dev", tag: nil do',
                     '  gem("rubocop-rails", )',
                     'end',
                     'git "https://github.com/rubocop-hq/rubocop-rspec.git", ref: nil, branch: nil, tag: "v1.13.0" do',
                     '  gem("rubocop-rspec", )',
                     'end',
                     'source "https://gems.sider.review" do',
                     '  gem("rubocop-sider", )',
                     'end',
                   ],
                   installer.gemfile_content
    end
  end

  def test_no_install
    specs = []

    mktmpdir do |path|
      installer = GemInstaller.new(
        shell: shell,
        specs: specs,
        home: path,
        ci_config_path_name: "sider.yml",
        trace_writer: trace_writer,
        constraints: {}
      )

      installer.install! do
        shell.capture3!("bundle", "exec", "gem", "list")
      end
    end
  end

  def test_install_success
    specs = [
      GemInstaller::Spec.new(name: "strong_json", version: ["0.5.0"])
    ]

    mktmpdir do |path|
      installer = GemInstaller.new(
        shell: shell,
        specs: specs,
        home: path,
        ci_config_path_name: "sider.yml",
        trace_writer: trace_writer,
        constraints: { "strong_json" => ["<= 0.8.0"] }
      )

      installer.install! do |hash|
        stdout, _ = shell.capture3("bundle", "exec", "gem", "list")
        assert_includes stdout.lines(chomp: true), "strong_json (0.5.0)"
        assert_equal "0.5.0", hash["strong_json"]
      end

      assert trace_writer.writer.any? {|message|
        message[:trace] == 'message' &&
          message[:message] == "  Specified version: 0.5.0"
      }
      assert trace_writer.writer.any? {|message|
        message[:trace] == 'message' &&
          message[:message] == "  Sider constraints: <= 0.8.0"
      }
    end
  end

  def test_install_failure
    specs = [
      GemInstaller::Spec.new(name: "strong_json", version: ["0.5.0"])
    ]

    mktmpdir do |path|
      installer = GemInstaller.new(
        shell: shell,
        specs: specs,
        home: path,
        ci_config_path_name: "sider.yml",
        trace_writer: trace_writer,
        constraints: { "strong_json" => ["> 0.6.0"] }
      )

      assert_raises GemInstaller::InstallationFailure do
        installer.install! do
        end
      end
    end
  end

  def test_from_gems
    specs = GemInstaller::Spec.from_gems([
                                           "rubocop",
                                           { "name" => "strong_json", "version" => "0.7.0", "source" => "https://my.gems.org" },
                                           { "name" => "rubocop-sider", "git" => { "repo" => "https://github.com/sider/rubocop-sider.git" } },
                                           { "name" => "node_harness", "git" => { "repo" => "git@github.com:sider/node_harness.git", "ref" => "e66806c02849a0d0bdea66be88b5967d5eb3305d" } },
                                           { "name" => "rubocop-rails", "git" => { "repo" => "https://github.com/rubocop-hq/rubocop-rails.git", "branch" => "dev" } },
                                           { "name" => "rubocop-rspec", "git" => { "repo" => "https://github.com/rubocop-hq/rubocop-rspec.git", "tag" => "v1.13.0" } },
                                         ])

    assert_equal [
                   GemInstaller::Spec.new(name: "rubocop", version: []),
                   GemInstaller::Spec.new(name: "strong_json", version: ["0.7.0"], source: GemInstaller::RubygemsSource.new("https://my.gems.org")),
                   GemInstaller::Spec.new(name: "rubocop-sider", version: [], source: GemInstaller::GitSource.new(repo: "https://github.com/sider/rubocop-sider.git")),
                   GemInstaller::Spec.new(name: "node_harness", version: [], source: GemInstaller::GitSource.new(repo: "git@github.com:sider/node_harness.git", ref: "e66806c02849a0d0bdea66be88b5967d5eb3305d")),
                   GemInstaller::Spec.new(name: "rubocop-rails", version: [], source: GemInstaller::GitSource.new(repo: "https://github.com/rubocop-hq/rubocop-rails.git", branch: "dev")),
                   GemInstaller::Spec.new(name: "rubocop-rspec", version: [], source: GemInstaller::GitSource.new(repo: "https://github.com/rubocop-hq/rubocop-rspec.git", tag: "v1.13.0")),
                 ], specs
  end

  def test_ensure_lockfile_with_gemfile_lock
    mktmpdir do |path|
      (path + "Gemfile").write(<<EOF)
source "https://rubygems.org"

gem 'activerecord'
gem 'strong_json'
gem 'rspec'
gem 'rubocop', git: "https://github.com/rubocop-hq/rubocop.git", tag: "v0.63.0"
gem 'jack_and_the_elastic_beanstalk', git: 'https://github.com/sider/jack_and_the_elastic_beanstalk.git'
EOF

      shell.push_dir(path) do
        Bundler.with_clean_env do
          shell.capture3!("bundle", "lock")
        end
      end

      content = (path + "Gemfile.lock").read
      content.gsub!("https://rubygems.org", "https://my.gems.org")
      (path + "Gemfile.lock").write content

      LockfileLoader.new(root_dir: path, shell: shell).ensure_lockfile do |lockfile|
        assert lockfile.spec_exists?("activerecord")
        assert lockfile.spec_exists?("strong_json")
        assert lockfile.spec_exists?("rspec")
        assert lockfile.spec_exists?("rubocop")
        assert lockfile.spec_exists?("jack_and_the_elastic_beanstalk")
        refute lockfile.spec_exists?("goodcheck")

        refute_nil lockfile.locked_version("activerecord")
        refute_nil lockfile.locked_version("strong_json")
        refute_nil lockfile.locked_version("rspec")
        refute_nil lockfile.locked_version("rubocop")
        refute_nil lockfile.locked_version("jack_and_the_elastic_beanstalk")
        assert_nil lockfile.locked_version("goodcheck")
      end
    end
  end

  def test_ensure_lockfile_without_gemfile_lock
    mktmpdir do |path|
      (path + "Gemfile").write(<<EOF)
source "https://rubygems.org"

gem 'activerecord'
gem 'strong_json'
gem 'rspec'
EOF

      LockfileLoader.new(root_dir: path, shell: shell).ensure_lockfile do |lockfile|
        assert lockfile.spec_exists?("activerecord")
        assert lockfile.spec_exists?("strong_json")
        assert lockfile.spec_exists?("rspec")
        refute lockfile.spec_exists?("rubocop")

        refute_nil lockfile.locked_version("activerecord")
        refute_nil lockfile.locked_version("strong_json")
        refute_nil lockfile.locked_version("rspec")
        assert_nil lockfile.locked_version("rubocop")
      end
    end
  end

  def test_ensure_lockfile_with_invalid_gemfile_only
    mktmpdir do |path|
      (path + "Gemfile").write(<<EOF)
gem 'rubocop', "< 0.59.0"
gem 'rubocop', "> 0.60.0"
EOF

      LockfileLoader.new(root_dir: path, shell: shell).ensure_lockfile do |lockfile|
        assert_empty lockfile.specs
      end
    end
  end

  def test_ensure_lockfile_with_conflict_gemfile_lock
    mktmpdir do |path|
      (path + "Gemfile").write(<<EOF)
source "https://rubygems.org"

<<<<<<< HEAD
gem "rubocop"
gem "goodcheck"
=======
gem "querly"
>>>>>>> add_querly
EOF

      (path + "Gemfile.lock").write(<<EOF)
GEM
  remote: https://rubygems.org/                                                                                                                 [33/1947]
  specs:                                                                                                                                                 
    activesupport (5.2.2)                                                                                                                                
      concurrent-ruby (~> 1.0, >= 1.0.2)                                                                                                                 
      i18n (>= 0.7, < 2)                                                                                                                                 
      minitest (~> 5.1)                                                                                                                                  
      tzinfo (~> 1.1)                                                                                                                                    
    ast (2.4.0)                                                                                                                                          
    concurrent-ruby (1.1.4)                                                                                                                              
<<<<<<< HEAD                                                                                                                                             
    goodcheck (1.4.1)                                                                                                                                    
      activesupport (~> 5.0)                                                                                                                             
      httpclient (~> 2.8.3)                                                                                                                              
      rainbow (~> 3.0.0)                                                                                                                                 
      strong_json (~> 0.7.1)                                                                                                                             
    httpclient (2.8.3)                                                                                                                                   
    i18n (1.5.3)                                                                                                                                         
      concurrent-ruby (~> 1.0)                                                                                                                           
    jaro_winkler (1.5.2)                                                                                                                                 
    minitest (5.11.3)                                                                                                                                    
    parallel (1.13.0)                                                                                                                                    
    parser (2.6.0.0)                                                                                                                                     
=======                                                                                                                                                  
    i18n (1.5.3)                                                                                                                                         
      concurrent-ruby (~> 1.0)                                                                                                                           
    minitest (5.11.3)                                                                                                                                    
    parser (2.5.3.0)                                                                                                                                     
>>>>>>> add_querly                                                                                                                                       
      ast (~> 2.4.0)                                                                                                                                     
    querly (0.14.0)                                                                                                                                      
      activesupport (~> 5.0)                                                                                                                             
      parser (~> 2.5.0)                                                                                                                                  
      rainbow (>= 2.1)
      thor (>= 0.19.0, < 0.21.0)
    rainbow (3.0.0)
<<<<<<< HEAD
    rubocop (0.63.1)
      jaro_winkler (~> 1.5.1)
      parallel (~> 1.10)
      parser (>= 2.5, != 2.5.1.1)
      powerpack (~> 0.1)
      rainbow (>= 2.2.2, < 4.0)
      ruby-progressbar (~> 1.7)
      unicode-display_width (~> 1.4.0)
    ruby-progressbar (1.10.0)
    strong_json (0.7.1)
    thread_safe (0.3.6)
    tzinfo (1.2.5)
      thread_safe (~> 0.1)
    unicode-display_width (1.4.1)
=======
    thor (0.20.3)
    thread_safe (0.3.6)
    tzinfo (1.2.5)
      thread_safe (~> 0.1)
>>>>>>> add_querly

PLATFORMS
  ruby

DEPENDENCIES
<<<<<<< HEAD
  goodcheck
  rubocop
=======
  querly
>>>>>>> add_querly

BUNDLED WITH
   1.17.1
EOF

      assert_raises LockfileLoader::InvalidGemfileLock do
        LockfileLoader.new(root_dir: path, shell: shell).ensure_lockfile do
          # noop
        end
      end
    end
  end

  def test_merge_specs
    default_specs = [
      GemInstaller::Spec.new(name: "rubocop", version: ["0.4.0"]),
      GemInstaller::Spec.new(name: "strong_json", version: ["0.4.0"])
    ]

    user_specs = [
      GemInstaller::Spec.new(name: "rubocop", version: ["0.5.0"], source: "https://some.source.org"),
      GemInstaller::Spec.new(name: "rubocop-rspec", version: ["1.2.3"])
    ]

    assert_equal [
                   GemInstaller::Spec.new(name: "rubocop", version: ["0.5.0"], source: "https://some.source.org"),
                   GemInstaller::Spec.new(name: "strong_json", version: ["0.4.0"]),
                   GemInstaller::Spec.new(name: "rubocop-rspec", version: ["1.2.3"])
                 ],
                 GemInstaller::Spec.merge(default_specs, user_specs)
  end

  def test_install_no_gems
    klass = Class.new(NodeHarness::Processor) do
      include NodeHarness::Ruby

      def ci_section
        { }
      end
    end

    mktmpdir do |path|
      processor = klass.new(guid: SecureRandom.uuid,
                            working_dir: path,
                            git_ssh_path: nil,
                            trace_writer: trace_writer)

      processor.install_gems([GemInstaller::Spec.new(name: "strong_json", version: ["0.5.0"])],
                         constraints: {}) do
        stdout, _ = processor.shell.capture3!("bundle", "show")
        assert_includes stdout.lines, "  * strong_json (0.5.0)\n"
      end
    end
  end

  def test_install_gems_with_gems
    klass = Class.new(NodeHarness::Processor) do
      include NodeHarness::Ruby

      def ci_section
        { "gems" => ["strong_json"] }
      end
    end

    mktmpdir do |path|
      (path + "Gemfile").write(<<EOF)
source "https://rubygems.org"

gem 'meowcop'
EOF

      shell.push_dir(path) do
        Bundler.with_clean_env do
          shell.capture3!("bundle", "lock")
        end
      end

      processor = klass.new(guid: SecureRandom.uuid,
                            working_dir: path,
                            git_ssh_path: nil,
                            trace_writer: trace_writer)

      processor.install_gems([GemInstaller::Spec.new(name: "rubocop", version: ["0.63.0"])],
                             optionals: [GemInstaller::Spec.new(name: "meowcop", version: ["1.17.1"])],
                             constraints: {}) do
        stdout, _ = processor.shell.capture3!("bundle", "show")
        assert_match(/\* rubocop/, stdout)
        assert_match(/\* strong_json/, stdout)
        refute_match(/\* meowcop/, stdout)
      end
    end
  end

  def test_install_gems_with_gems_failure
    klass = Class.new(NodeHarness::Processor) do
      include NodeHarness::Ruby

      def ci_section
        { "gems" => ["no such gem"] }
      end
    end

    mktmpdir do |path|
      processor = klass.new(guid: SecureRandom.uuid,
                            working_dir: path,
                            git_ssh_path: nil,
                            trace_writer: trace_writer)

      assert_raises GemInstaller::InstallationFailure do
        processor.install_gems([GemInstaller::Spec.new(name: "rubocop", version: ["0.63.0"])],
                               optionals: [GemInstaller::Spec.new(name: "meowcop", version: ["1.17.1"])],
                               constraints: {}) do
          # nop
        end
      end
    end
  end

  def test_install_gems_with_invalid_gem_definition
    klass = Class.new(NodeHarness::Processor) do
      include NodeHarness::Ruby

      def ci_section
        { "gems" => [{ "version" => "0.62.0" }] }
      end
    end

    mktmpdir do |path|
      processor = klass.new(guid: SecureRandom.uuid,
                            working_dir: path,
                            git_ssh_path: nil,
                            trace_writer: trace_writer)

      assert_raises GemInstaller::Spec::InvalidGemDefinition do
        processor.install_gems([GemInstaller::Spec.new(name: "rubocop", version: ["0.63.0"])],
                               optionals: [GemInstaller::Spec.new(name: "meowcop", version: ["1.17.1"])],
                               constraints: {}) do
          # nop
        end
      end
    end
  end

  def test_install_gems_with_optionals
    klass = Class.new(NodeHarness::Processor) do
      include NodeHarness::Ruby
    end

    mktmpdir do |path|
      (path + "Gemfile").write(<<EOF)
source "https://rubygems.org"

gem 'meowcop'
EOF

      shell.push_dir(path) do
        Bundler.with_clean_env do
          shell.capture3!("bundle", "lock")
        end
      end

      processor = klass.new(guid: SecureRandom.uuid,
                            working_dir: path,
                            git_ssh_path: nil,
                            trace_writer: trace_writer)

      processor.install_gems([GemInstaller::Spec.new(name: "rubocop", version: ["0.63.0"])],
                             optionals: [GemInstaller::Spec.new(name: "meowcop", version: ["1.17.1"])],
                             constraints: {}) do
        stdout, _ = processor.shell.capture3!("bundle", "show")
        assert_match(/\* rubocop/, stdout)
        assert_match(/\* meowcop/, stdout)
      end
    end
  end

  def test_install_gems_with_gemfile_lock
    klass = Class.new(NodeHarness::Processor) do
      include NodeHarness::Ruby

      def ci_section
        {
          "gems" => [
            "strong_json",
            { "name" => "jack_and_the_elastic_beanstalk", "version" => "0.2.2" }
          ]
        }
      end
    end

    mktmpdir do |path|
      (path + "Gemfile").write(<<EOF)
source "https://rubygems.org"

gem 'rubocop', '0.62.0'
gem 'strong_json', '0.7.1'
gem 'jack_and_the_elastic_beanstalk', '0.2.3'
gem 'meowcop'
gem 'activerecord'
EOF

      shell.push_dir(path) do
        Bundler.with_clean_env do
          shell.capture3!("bundle", "lock")
        end
      end

      processor = klass.new(guid: SecureRandom.uuid,
                            working_dir: path,
                            git_ssh_path: nil,
                            trace_writer: trace_writer)

      processor.install_gems([GemInstaller::Spec.new(name: "rubocop", version: ["0.63.0"])],
                             optionals: [GemInstaller::Spec.new(name: "meowcop", version: ["1.17.1"])],
                             constraints: { "rubocop" => ["> 0.60.0"] }) do
        stdout, _ = processor.shell.capture3!("bundle", "show")
        assert_match(/\* rubocop \(0.62.0\)/, stdout)
        assert_match(/\* strong_json \(0.7.1\)/, stdout)
        assert_match(/\* jack_and_the_elastic_beanstalk \(0.2.2\)/, stdout)
        refute_match(/\* meowcop/, stdout)
        refute_match(/\* activerecord/, stdout)
      end
    end
  end


  def test_install_gems_with_gemfile_lock_which_does_not_satisfy_constraints
    klass = Class.new(NodeHarness::Processor) do
      include NodeHarness::Ruby
    end

    mktmpdir do |path|
      (path + "Gemfile").write(<<EOF)
source "https://rubygems.org"

gem 'rubocop', '0.62.0'
EOF

      shell.push_dir(path) do
        Bundler.with_clean_env do
          shell.capture3!("bundle", "lock")
        end
      end

      processor = klass.new(guid: SecureRandom.uuid,
                            working_dir: path,
                            git_ssh_path: nil,
                            trace_writer: trace_writer)

      processor.install_gems([GemInstaller::Spec.new(name: "rubocop", version: ["0.66.0"])],
                             constraints: { "rubocop" => ["> 0.65.0"] }) do
        assert_equal 1, processor.warnings.count
        assert_equal <<~MESSAGE, processor.warnings.first[:message]
          Sider tried to install `rubocop 0.62.0` according to your `Gemfile.lock`, but it installs `0.66.0` instead.
          Because `0.62.0` does not satisfy the Sider constraints ["> 0.65.0"].

          If you want to use a different version of `rubocop`, update your `Gemfile.lock` to satisfy the constraint or specify the gem version in your `sider.yml`.
          See https://help.sider.review/getting-started/custom-configuration#gems-option
        MESSAGE

        stdout, _ = processor.shell.capture3!("bundle", "show")
        assert_match(/\* rubocop \(0.66.0\)/, stdout)
      end
    end
  end

  def test_install_gems_with_gems_which_does_not_satisfy_constraints
    klass = Class.new(NodeHarness::Processor) do
      include NodeHarness::Ruby

      def ci_section
        {
          "gems" => [
            { "name" => "rubocop", "version" => "0.62.0" }
          ]
        }
      end
    end

    mktmpdir do |path|
      processor = klass.new(guid: SecureRandom.uuid,
                            working_dir: path,
                            git_ssh_path: nil,
                            trace_writer: trace_writer)

      assert_raises GemInstaller::InstallationFailure do
        processor.install_gems([GemInstaller::Spec.new(name: "rubocop", version: ["0.66.0"])],
                               constraints: { "rubocop" => ["> 0.65.0"] }) do
          # noop
        end
      end
    end
  end

  def test_install_gems_with_other_sources
    klass = Class.new(NodeHarness::Processor) do
      include NodeHarness::Ruby

      def ci_section
        {
          "gems" => [
            { "name" => "rails-assets-bootstrap", "source" => "https://rails-assets.org" },
          ]
        }
      end
    end

    mktmpdir do |path|
      processor = klass.new(guid: SecureRandom.uuid,
                            working_dir: path,
                            git_ssh_path: nil,
                            trace_writer: trace_writer)

      processor.install_gems([GemInstaller::Spec.new(name: "rubocop", version: ["0.63.0"])],
                             optionals: [],
                             constraints: {}) do
        stdout, _ = processor.shell.capture3!("bundle", "show")
        assert_match(/\* rails-assets-bootstrap/, stdout)
      end
    end
  end

  def test_install_gems_with_git_sources
    klass = Class.new(NodeHarness::Processor) do
      include NodeHarness::Ruby

      def ci_section
        {
          "gems" => [
            { "name" => "jack_and_the_elastic_beanstalk", "git" => { "repo" => "https://github.com/sider/jack_and_the_elastic_beanstalk.git" } },
            { "name" => "meowcop", "git" => { "repo" => "https://github.com/sider/meowcop.git", "tag" => "v1.16.0" } },
            { "name" => "configure", "git" => { "repo" => "https://github.com/sider/configure.git", "ref" => "9b4703aea9dee97fe0ada15812c46ecf622c352c" } },
            { "name" => "ruby_private_gem", "git" => { "repo" => "git@github.com:sider/ruby_private_gem.git", "branch" => "gem" } }
          ]
        }
      end
    end

    mktmpdir do |path|
      NodeHarness::Workspace.open(base: nil, base_key: nil,
                                  head: (Pathname(__dir__) + "data/foo.tgz").to_s, head_key: nil,
                                  working_dir: path,
                                  ssh_key: (Pathname(__dir__) + "data/ruby_private_gem_deploy_key").to_s,
                                  trace_writer: trace_writer) do |workspace|
        processor = klass.new(guid: SecureRandom.uuid,
                              working_dir: path,
                              git_ssh_path: workspace.git_ssh_path,
                              trace_writer: trace_writer)
        processor.install_gems([GemInstaller::Spec.new(name: "rubocop", version: ["0.63.0"])],
                               optionals: [],
                               constraints: {}) do
          stdout, _ = processor.shell.capture3!("bundle", "show")
          assert_match(/\* rubocop/, stdout)
          assert_match(/\* jack_and_the_elastic_beanstalk/, stdout)
          assert_match(/\* meowcop \(1.16.0 2f52514\)/, stdout)
          assert_match(/\* configure \(0.1.0 9b4703a\)/, stdout)
          assert_match(/\* ruby_private_gem/, stdout)
        end
      end
    end
  end

  def test_install_gems_with_only_git_sources
    klass = Class.new(NodeHarness::Processor) do
      include NodeHarness::Ruby

      def ci_section
        {
          "gems" => [
            { "name" => "rubocop", "git" => { "repo" => "https://github.com/rubocop-hq/rubocop.git", "tag" => "v0.63.1" } },
          ]
        }
      end
    end

    mktmpdir do |path|
      processor = klass.new(guid: SecureRandom.uuid,
                            working_dir: path,
                            git_ssh_path: nil,
                            trace_writer: trace_writer)

      processor.install_gems([], optionals: [], constraints: {}) do
        stdout, _ = processor.shell.capture3!("bundle", "show")
        assert_match(/\* rubocop/, stdout)
      end
    end
  end
end
