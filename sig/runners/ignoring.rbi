class Runners::Ignoring
  attr_reader working_dir: Pathname
  attr_reader trace_writer: TraceWriter
  attr_reader config: Config

  def initialize: (working_dir: Pathname, trace_writer: TraceWriter, config: Config) -> void
  def delete_ignored_files!: () -> void
  def ignores: () -> Array<String>
  def with_gitignore: () { (Array<Pathname>) -> void } -> void
end