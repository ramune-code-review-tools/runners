target :lib do
  repo_path ".gem_rbs_collection/"

  check "exe/*"
  check "lib/**/*.rb"

  # Standard libraries
  library "digest"
  library "optparse"
  library "rubygems"
  library "set"
  library "tempfile"
  library "tmpdir"
  library "uri"
  library "yaml", "dbm", "pstore" # HACK: `dbm` and `pstore` required by `yaml`

  # 3rd-party libraries
  # ...
end
