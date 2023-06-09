module Runners
  class Warnings
    attr_reader :trace_writer

    def initialize(trace_writer: nil)
      @list = []
      @trace_writer = trace_writer
    end

    def add(message, file: nil, limit: 1000)
      message = message.strip
      trace_writer&.warning(message, file: file)
      new_warning = { message: truncate_message(message, limit), file: file }
      @list << new_warning unless @list.include? new_warning
    end

    def add_warning_if_deprecated_version(analyzer_name, current:, minimum:, deadline: nil)
      if Gem::Version.new(current) < Gem::Version.new(minimum)
        add "#{analyzer_name} #{current} is deprecated and will be dropped #{deadline_text(deadline)}. Please update to #{minimum} or higher."
      end
    end

    def add_warning_for_deprecated_linter(old:, new:, links: [], deadline: nil)
      message = "The support for #{old} is deprecated and will be removed #{deadline_text(deadline)}. Please migrate to #{new}."
      unless links.empty?
        message << " See below:\n"
        message << links.map { |link| "- #{link}\n" }.join
      end
      add message
    end

    def size
      @list.size
    end

    def empty?
      @list.empty?
    end

    def each(&block)
      @list.each(&block)
    end

    def to_a
      @list.to_a
    end
    alias as_json to_a

    private

    def deadline_text(time)
      time&.strftime("on %B %-d, %Y") || "soon"
    end

    def truncate_message(message, limit)
      if message.size > limit
        message = message.slice(0, limit).to_s + "\n...(truncated)"
      end
      message
    end
  end
end
