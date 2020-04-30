s = Runners::Testing::Smoke

s.add_test(
  "success",
  type: "success",
  analyzer: { name: "Checkstyle", version: "8.32" },
  issues: [
    {
      message: "The name of the outer type and the file do not match.",
      links: %w[https://checkstyle.org/config_misc.html#OuterTypeFilename],
      id: "com.puppycrawl.tools.checkstyle.checks.OuterTypeFilenameCheck#b81ef5",
      path: "src/Hello.java",
      location: { start_line: 3 },
      object: { severity: "warning" },
      git_blame_info: nil
    },
    {
      message: "'method def' child has incorrect indentation level 8, expected level should be 4.",
      links: %w[https://checkstyle.org/config_misc.html#Indentation],
      id: "com.puppycrawl.tools.checkstyle.checks.indentation.IndentationCheck#2aa7da",
      path: "src/Hello.java",
      location: { start_line: 6 },
      object: { severity: "warning" },
      git_blame_info: nil
    },
    {
      message: "'method def modifier' has incorrect indentation level 4, expected level should be 2.",
      links: %w[https://checkstyle.org/config_misc.html#Indentation],
      id: "com.puppycrawl.tools.checkstyle.checks.indentation.IndentationCheck#d0bdde",
      path: "src/Hello.java",
      location: { start_line: 5 },
      object: { severity: "warning" },
      git_blame_info: nil
    },
    {
      message: "'method def rcurly' has incorrect indentation level 4, expected level should be 2.",
      links: %w[https://checkstyle.org/config_misc.html#Indentation],
      id: "com.puppycrawl.tools.checkstyle.checks.indentation.IndentationCheck#e7930a",
      path: "src/Hello.java",
      location: { start_line: 7 },
      object: { severity: "warning" },
      git_blame_info: nil
    }
  ]
)

s.add_test(
  "config",
  type: "success",
  analyzer: { name: "Checkstyle", version: "8.32" },
  issues: [
    {
      message: "Parameter args should be final.",
      links: %w[https://checkstyle.org/config_misc.html#FinalParameters],
      id: "com.puppycrawl.tools.checkstyle.checks.FinalParametersCheck#0bbcea",
      path: "src/Main.java",
      location: { start_line: 5 },
      object: { severity: "error" },
      git_blame_info: nil
    },
    {
      message: "Utility classes should not have a public or default constructor.",
      links: %w[https://checkstyle.org/config_design.html#HideUtilityClassConstructor],
      id: "com.puppycrawl.tools.checkstyle.checks.design.HideUtilityClassConstructorCheck#97f5fb",
      path: "src/Main.java",
      location: { start_line: 3 },
      object: { severity: "error" },
      git_blame_info: nil
    },
    {
      message: "Missing package-info.java file.",
      links: %w[https://checkstyle.org/config_javadoc.html#JavadocPackage],
      id: "com.puppycrawl.tools.checkstyle.checks.javadoc.JavadocPackageCheck#1cbcec",
      path: "src/Main.java",
      location: { start_line: 1 },
      object: { severity: "error" },
      git_blame_info: nil
    },
    {
      message: "Missing a Javadoc comment.",
      links: %w[https://checkstyle.org/config_javadoc.html#MissingJavadocMethod],
      id: "com.puppycrawl.tools.checkstyle.checks.javadoc.MissingJavadocMethodCheck#0cbebf",
      path: "src/Main.java",
      location: { start_line: 5 },
      object: { severity: "error" },
      git_blame_info: nil
    }
  ]
)

s.add_test(
  "failure",
  type: "failure",
  message: "Analysis failed. See the log for details.",
  analyzer: { name: "Checkstyle", version: "8.32" }
)

s.add_test(
  "broken_sideci_yml",
  type: "failure",
  message:
    "The value of the attribute `$.linter.checkstyle.exclude` in your `sideci.yml` is invalid. Please fix and retry.",
  analyzer: :_
)

s.add_test(
  "properties",
  type: "success",
  issues: [
    {
      message: "Line is longer than 50 characters (found 67).",
      links: %w[https://checkstyle.org/config_sizes.html#LineLength],
      id: "com.puppycrawl.tools.checkstyle.checks.sizes.LineLengthCheck#446163",
      path: "src/Main.java",
      location: { start_line: 3 },
      object: { severity: "error" },
      git_blame_info: nil
    },
    {
      message: "Line is longer than 50 characters (found 63).",
      links: %w[https://checkstyle.org/config_sizes.html#LineLength],
      id: "com.puppycrawl.tools.checkstyle.checks.sizes.LineLengthCheck#6a9962",
      path: "myruleset.xml",
      location: { start_line: 4 },
      object: { severity: "error" },
      git_blame_info: nil
    },
    {
      message: "Line is longer than 50 characters (found 54).",
      links: %w[https://checkstyle.org/config_sizes.html#LineLength],
      id: "com.puppycrawl.tools.checkstyle.checks.sizes.LineLengthCheck#8de3eb",
      path: "myruleset.xml",
      location: { start_line: 8 },
      object: { severity: "error" },
      git_blame_info: nil
    },
    {
      message: "Line is longer than 50 characters (found 57).",
      links: %w[https://checkstyle.org/config_sizes.html#LineLength],
      id: "com.puppycrawl.tools.checkstyle.checks.sizes.LineLengthCheck#a134cc",
      path: "myruleset.xml",
      location: { start_line: 3 },
      object: { severity: "error" },
      git_blame_info: nil
    }
  ],
  analyzer: { name: "Checkstyle", version: "8.32" }
)

s.add_test(
  "syntax_error",
  type: "failure",
  message: "Analysis failed. See the log for details.",
  analyzer: { name: "Checkstyle", version: "8.32" }
)
