s = Runners::Testing::Smoke

default_version = "1.6.8"

# empty yaml file reports issue about missing section
s.add_test(
  "empty",
  type: "success",
  issues: [
    {
      id: "syntax-check",
      path: "empty.yml",
      location: { start_line: 1, start_column: 1 },
      message: "\"jobs\" section is missing in workflow",
      object: { shellcheck: nil, pyflakes: nil },
      links: [],
      git_blame_info: { commit: :_, line_hash: "58b63e273b964039d6ef432a415df3f177c818e5", original_line: 1, final_line: 1 }
    }
  ],
  analyzer: { name: "actionlint", version: default_version }
)

# simple workflow file reports no issues
s.add_test(
  "noissue",
  type: "success",
  issues: [],
  analyzer: { name: "actionlint", version: default_version }
)

# shellcheck reports issues
s.add_test(
  "shellcheck",
  type: "success",
  issues: [
    {
      id: "shellcheck/SC2086",
      path: "shellcheck.yml",
      location: { start_line: 12, start_column: 9 },
      message: "shellcheck reported issue in this script: SC2086:info:1:14: Double quote to prevent globbing and word splitting",
      object: {
        shellcheck: {
          id: "SC2086",
          severity: "info",
          line: 1,
          column: 14,
          message: "Double quote to prevent globbing and word splitting",
          url: "https://github.com/koalaman/shellcheck/wiki/SC2086"
        },
        pyflakes: nil
      },
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2086"],
      git_blame_info: { commit: :_, line_hash: "e51856dd007fb0008697c80234cc96f8ea1d353b", original_line: 12, final_line: 12 }
    }
  ],
  analyzer: { name: "actionlint", version: default_version }
)

# pyflakes reports issues
s.add_test(
  "pyflakes",
  type: "success",
  issues: [
    {
      id: "pyflakes",
      path: "pyflakes.yml",
      location: { start_line: 9, start_column: 9 },
      message: "pyflakes reported issue in this script: 1:7 undefined name 'hello'",
      object: {
        shellcheck: nil,
        pyflakes: {
          line: 1,
          column: 7,
          message: "undefined name 'hello'"
        }
      },
      links: [],
      git_blame_info: { commit: :_, line_hash: "d2fb0982403f3ed337409b15becaa960e36bfd71", original_line: 9, final_line: 9 }
    }
  ],
  analyzer: { name: "actionlint", version: default_version }
)

# actionlint automatically locates workflows in .github/workflows
s.add_test(
  "success",
  type: "success",
  issues: [
    {
      id: "syntax-check",
      path: ".github/workflows/success.yml",
      location: { start_line: 14, start_column: 1 },
      message: "unexpected key \"unexpected_key\" for \"workflow\" section. expected one of \"concurrency\", \"defaults\", \"env\", \"jobs\", \"name\", \"on\", \"permissions\"",
      object: { shellcheck: nil, pyflakes: nil },
      links: [],
      git_blame_info: { commit: :_, line_hash: "6a005e4d69e1891e821aebf11b2ae1561e18fd5f", original_line: 14, final_line: 14 }
    }
  ],
  analyzer: { name: "actionlint", version: default_version }
)

# -ignore option suppresses error messages which match given regex
s.add_test(
  "ignore",
  type: "success",
  issues: [
    {
      id: "events",
      path: "ignore.yml",
      location: { start_line: 1, start_column: 5 },
      message: "unknown Webhook event \"click\". see https://docs.github.com/en/actions/learn-github-actions/events-that-trigger-workflows#webhook-events for list of all Webhook event names",
      object: { shellcheck: nil, pyflakes: nil },
      links: [],
      git_blame_info: { commit: :_, line_hash: "92d335cfda83dc2c0fe9009891ea4eae9f96f17c", original_line: 1, final_line: 1 }
    }
  ],
  analyzer: { name: "actionlint", version: default_version }
)

s.add_test(
  "noproject",
  type: "success",
  issues: [],
  warnings: [
    { message: "no project was found in any parent directories of \".\". check workflows directory is put correctly in your Git repository", file: nil }
  ],
  analyzer: { name: "actionlint", version: default_version }
)

s.add_test(
  "noyaml",
  type: "success",
  issues: [],
  warnings: [
    { message: "no YAML file was found in \"/home/analyzer_runner/project/.github/workflows\"", file: nil }
  ],
  analyzer: { name: "actionlint", version: default_version }
)

# this test case reports multiple issues
s.add_test(
  "multiple",
  type: "success",
  issues: [
    {
      id: "events",
      path: "multiple.yml",
      location: { start_line: 1, start_column: 5 },
      message: "unknown Webhook event \"click\". see https://docs.github.com/en/actions/learn-github-actions/events-that-trigger-workflows#webhook-events for list of all Webhook event names",
      object: { shellcheck: nil, pyflakes: nil },
      links: [],
      git_blame_info: { commit: :_, line_hash: "92d335cfda83dc2c0fe9009891ea4eae9f96f17c", original_line: 1, final_line: 1 }
    },
    {
      id: "job-needs",
      path: "multiple.yml",
      location: { start_line: 3, start_column: 3 },
      message: "job \"prepare\" needs job \"build\" which does not exist in this workflow",
      object: { shellcheck: nil, pyflakes: nil },
      links: [],
      git_blame_info: { commit: :_, line_hash: "7f315ab055942581cbf8071c788620de15968bbd", original_line: 3, final_line: 3 }
    },
    {
      id: "syntax-check",
      path: "multiple.yml",
      location: { start_line: 8, start_column: 5 },
      message: "unexpected key \"unexpected\" for \"job\" section. expected one of \"concurrency\", \"container\", \"continue-on-error\", \"defaults\", \"env\", \"environment\", \"if\", \"name\", \"needs\", \"outputs\", \"permissions\", \"runs-on\", \"secrets\", \"services\", \"steps\", \"strategy\", \"timeout-minutes\", \"uses\", \"with\"",
      object: { shellcheck: nil, pyflakes: nil },
      links: [],
      git_blame_info: { commit: :_, line_hash: "fb5ad3629930fef3a268a0542176342a0fd53fb7", original_line: 8, final_line: 8 }
    }
  ],
  analyzer: { name: "actionlint", version: default_version }
)

# this test case checks configuration with mutliple targets
s.add_test(
  "multitarget",
  type: "success",
  issues: [
    {
      id: "events",
      path: "onclick.yml",
      location: { start_line: 4, start_column: 5 },
      message: "unknown Webhook event \"click\". see https://docs.github.com/en/actions/learn-github-actions/events-that-trigger-workflows#webhook-events for list of all Webhook event names",
      object: { shellcheck: nil, pyflakes: nil },
      links: [],
      git_blame_info: { commit: :_, line_hash: "92d335cfda83dc2c0fe9009891ea4eae9f96f17c", original_line: 4, final_line: 4 }
    },
    {
      id: "syntax-check",
      path: "unexpected_key.yml",
      location: { start_line: 14, start_column: 1 },
      message: "unexpected key \"unexpected_key\" for \"workflow\" section. expected one of \"concurrency\", \"defaults\", \"env\", \"jobs\", \"name\", \"on\", \"permissions\"",
      object: { shellcheck: nil, pyflakes: nil },
      links: [],
      git_blame_info: { commit: :_, line_hash: "6a005e4d69e1891e821aebf11b2ae1561e18fd5f", original_line: 14, final_line: 14 }
    }
  ],
  analyzer: { name: "actionlint", version: default_version }
)
