Smoke = Runners::Testing::Smoke

Smoke.add_test(
  "success",
  {
    guid: "test-guid",
    timestamp: :_,
    type: "success",
    analyzer: { name: 'javasee', version: "0.1.2" },
    issues: [
      {
        id: "hello",
        path: "src/Hello.java",
        location: { start_line: 6, start_column: 9, end_line: 6, end_column: 48 },
        message: "Hello world\n",
        links: [],
        object: {
          id: "hello",
          message: "Hello world\n",
          justifications: []
        }
      }
    ],
  }
)

Smoke.add_test(
  "config",
  {
    guid: "test-guid",
    timestamp: :_,
    type: "success",
    analyzer: { name: 'javasee', version: :_ },
    issues: [
      {
        id: "hello",
        path: "src/Main.java",
        location: { start_line: 6, start_column: 9, end_line: 6, end_column: 48 },
        message: "Hello world\n",
        links: [],
        object: {
          id: "hello",
          message: "Hello world\n",
          justifications: []
        }
      }
    ],
  }
)

Smoke.add_test("failure", {
  guid: "test-guid",
  timestamp: :_,
  type: "failure",
  analyzer: { name: 'javasee', version: :_ },
  message: :_
})

Smoke.add_test("broken_sider_yml", {
  guid: "test-guid",
  timestamp: :_,
  type: "failure",
  analyzer: nil,
  message: "Invalid configuration in `sider.yml`: unexpected value at config: `$.linter.javasee.dir[2]`"
})
