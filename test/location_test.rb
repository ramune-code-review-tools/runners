require "test_helper"

class LocationTest < Minitest::Test
  Location = Runners::Location

  def test_as_json
    assert_equal(
      { start_line: 1, start_column: 2, end_line: 3, end_column: 4 },
      Location.new(start_line: 1, start_column: 2, end_line: 3, end_column: 4).as_json,
    )
    assert_equal(
      { start_line: 1, end_line: 3 },
      Location.new(start_line: 1, start_column: nil, end_line: 3, end_column: nil).as_json,
    )
    assert_equal(
      { start_line: 1 },
      Location.new(start_line: 1).as_json,
    )
  end

  def test_to_s
    assert_equal(
      "{ start_line=1, start_column=2, end_line=3, end_column=4 }",
      Location.new(start_line: 1, start_column: 2, end_line: 3, end_column: 4).to_s,
    )
    assert_equal(
      "{ start_line=1, start_column=nil, end_line=nil, end_column=nil }",
      Location.new(start_line: 1).to_s,
    )
  end

  def test_include_line
    assert Location.new(start_line: 1).include_line?(1)
    refute Location.new(start_line: 1).include_line?(2)
    refute Location.new(start_line: nil).include_line?(1)

    assert Location.new(start_line: 1, end_line: 1).include_line?(1)
    assert Location.new(start_line: 1, end_line: 2).include_line?(1)
    assert Location.new(start_line: 1, end_line: 2).include_line?(2)
    refute Location.new(start_line: 1, end_line: 2).include_line?(0)
    refute Location.new(start_line: 1, end_line: 2).include_line?(3)
  end
end
