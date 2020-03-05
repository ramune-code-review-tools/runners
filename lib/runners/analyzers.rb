module Runners
  class Analyzers
    def name(id)
      analyzer(id).fetch(:name)
    end

    def github(id)
      analyzer(id).fetch(:github).then { |repo| "https://github.com/#{repo}" }
    end

    def doc(id)
      analyzer(id).fetch(:doc).then { |path| "https://help.sider.review/#{path}" }
    end

    def deprecated?(id)
      analyzer(id).fetch(:deprecated, false)
    end

    private

    def content
      @content ||= begin
        file = Pathname(__dir__).join("../../analyzers.yml")
        YAML.safe_load(file.read, symbolize_names: true).fetch(:analyzers).freeze
      end
    end

    def analyzer(id)
      content.fetch(id.to_sym)
    end
  end
end