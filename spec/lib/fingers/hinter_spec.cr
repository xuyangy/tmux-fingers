require "spec"
require "../../spec_helper.cr"
require "../../../src/fingers/hinter"
require "../../../src/fingers/state"
require "../../../src/fingers/config"

record StateDouble, selected_hints : Array(String)

class TextOutput < ::Fingers::Printer
  def initialize
    @contents = ""
  end

  def print(msg)
    self.contents += msg
  end

  def flush
  end

  property :contents
end

def generate_lines
  input = 50.times.map do
    10.times.map do
      rand.to_s.split(".").last[0..15].rjust(16, '0')
    end.join(" ")
  end.join("\n")
end

describe Fingers::Hinter do
  it "works in a grid of lines" do
    width = 100
    input = generate_lines
    output = TextOutput.new

    patterns = Fingers::Config::BUILTIN_PATTERNS.values.to_a
    alphabet = "asdf".split("")

    hinter = Fingers::Hinter.new(
      input: input.split("\n"),
      width: width,
      patterns: patterns,
      state: ::Fingers::State.new,
      alphabet: alphabet,
      output: output,
    )
  end

  it "only highlights captured groups" do
    width = 100
    input = "
On branch ruby-rewrite-more-like-crystal-rewrite-amirite
Your branch is up to date with 'origin/ruby-rewrite-more-like-crystal-rewrite-amirite'.

Changes to be committed:
  (use \"git restore --staged <file>...\" to unstage)
        modified:   spec/lib/fingers/match_formatter_spec.cr

Changes not staged for commit:
  (use \"git add <file>...\" to update what will be committed)
  (use \"git restore <file>...\" to discard changes in working directory)
        modified:   .gitignore
        modified:   spec/lib/fingers/hinter_spec.cr
        modified:   spec/spec_helper.cr
        modified:   src/fingers/cli.cr
        modified:   src/fingers/dirs.cr
        modified:   src/fingers/match_formatter.cr
    "
    output = TextOutput.new

    patterns = Fingers::Config::BUILTIN_PATTERNS.values.to_a
    patterns << "On branch (?<capture>.*)"
    alphabet = "asdf".split("")

    hinter = Fingers::Hinter.new(
      input: input.split("\n"),
      width: width,
      patterns: patterns,
      state: ::Fingers::State.new,
      alphabet: alphabet,
      output: output,
    )
  end

  it "only reuses hints when allow duplicates is false" do
    width = 100
    output = TextOutput.new

    patterns = Fingers::Config::BUILTIN_PATTERNS.values.to_a
    alphabet = "asdf".split("")

    input = "
          modified:   src/fingers/cli.cr
          modified:   src/fingers/cli.cr
          modified:   src/fingers/cli.cr
    "

    hinter = Fingers::Hinter.new(
      input: input.split("\n"),
      width: width,
      patterns: patterns,
      state: ::Fingers::State.new,
      alphabet: alphabet,
      output: output,
      reuse_hints: false
    )

    hinter.run
  end

  it "can rerender when not reusing hints" do
    width = 100
    output = TextOutput.new

    patterns = Fingers::Config::BUILTIN_PATTERNS.values.to_a
    alphabet = "asdf".split("")

    input = "
          modified:   src/fingers/cli.cr
          modified:   src/fingers/cli.cr
          modified:   src/fingers/cli.cr
    "

    hinter = Fingers::Hinter.new(
      input: input.split("\n"),
      width: width,
      patterns: patterns,
      state: ::Fingers::State.new,
      alphabet: alphabet,
      output: output,
      reuse_hints: false
    )

    hinter.run
    hinter.run
  end

  it "hides the part of the hint that was already typed" do
    width = 40
    patterns = ["[a-z]{10}"]
    alphabet = "asd".split("")

    input = "
aaaaaaaaaa bbbbbbbbbb cccccccccc
dddddddddd eeeeeeeeee ffffffffff
"

    formatter = Fingers::MatchFormatter.new(
      hint_style: "[",
      highlight_style: "]",
      selected_hint_style: "[",
      selected_highlight_style: "]",
      backdrop_style: "",
      hint_position: "left",
      reset_sequence: ""
    )

    render = ->(typed : String) {
      state = ::Fingers::State.new
      state.input = typed
      output = TextOutput.new

      Fingers::Hinter.new(
        input: input.split("\n"),
        width: width,
        patterns: patterns,
        state: state,
        alphabet: alphabet,
        output: output,
        formatter: formatter
      ).run

      output.contents
    }

    render.call("").should contain("[das]aaaaaaa")
    # after typing "d", the leading "d" is dropped from every visible hint
    render.call("d").should contain("[as]aaaaaaaa")
    render.call("da").should contain("[s]aaaaaaaaa")
    # hints not matching the input stay hidden
    render.call("d").should_not contain("[s]eeeeeeeee")
  end

  it "hides the typed prefix of already selected hints in multi mode" do
    width = 40
    patterns = ["[a-z]{10}"]
    alphabet = "asd".split("")

    input = "
aaaaaaaaaa bbbbbbbbbb cccccccccc
dddddddddd eeeeeeeeee ffffffffff
"

    formatter = Fingers::MatchFormatter.new(
      hint_style: "[",
      highlight_style: "]",
      selected_hint_style: "{",
      selected_highlight_style: "}",
      backdrop_style: "",
      hint_position: "left",
      reset_sequence: ""
    )

    render = ->(typed : String, selected : Array(String)) {
      state = ::Fingers::State.new
      state.multi_mode = true
      state.input = typed
      state.selected_hints = selected
      output = TextOutput.new

      Fingers::Hinter.new(
        input: input.split("\n"),
        width: width,
        patterns: patterns,
        state: state,
        alphabet: alphabet,
        output: output,
        formatter: formatter
      ).run

      output.contents
    }

    # "ds" picked, nothing typed yet: full hint, selected styles
    render.call("", ["ds"]).should contain("{ds}dddddddd")
    # typing "d" strips the prefix from the selected hint too
    render.call("d", ["ds"]).should contain("{s}ddddddddd")
    # unselected hints keep the normal styles while being stripped
    render.call("d", ["ds"]).should contain("[as]aaaaaaaa")
  end
end
