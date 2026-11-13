require "spec"
require "../../spec_helper.cr"
require "../../../src/fingers/view"
require "../../../src/fingers/hinter"
require "../../../src/fingers/state"
require "../../../src/fingers/config"

class ViewTextOutput < ::Fingers::Printer
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

# A path that a program wrapped onto two rows, with the hanging indent that
# Claude Code puts before continuation rows.
SPLIT_PATH_INPUT = [
  "see /Users/me/projects/tmux-fingers/src/fin",
  "  gers/commands/start.cr for details",
]

def build_view(lines : Array(String), state : Fingers::State)
  output = ViewTextOutput.new

  hinter = Fingers::Hinter.new(
    input: lines,
    width: 80,
    patterns: [Fingers::Config::BUILTIN_PATTERNS[:path]],
    state: state,
    alphabet: "asdf".split(""),
    output: output,
  )

  pane = Tmux::Pane.from_json(%({
    "pane_id": "%1",
    "window_id": "@1",
    "pane_width": 80,
    "pane_height": 24,
    "pane_current_path": "/tmp",
    "pane_in_mode": false,
    "scroll_position": null,
    "window_zoomed_flag": false
  }))

  view = Fingers::View.new(
    hinter: hinter,
    output: output,
    original_pane: pane,
    state: state,
    tmux: Tmux.new("3.4"),
    mode: "default",
  )

  {view, hinter}
end

def hint_for(hinter : Fingers::Hinter, text : String) : String
  ("a".."z").each do |a|
    ["", *("a".."z").to_a].each do |b|
      target = hinter.lookup(a + b)
      return a + b if target && target.text == text
    end
  end

  raise "no hint for #{text}"
end

def select_hint(view : Fingers::View, hint : String, modifier = "main")
  hint.each_char { |char| view.process_input("hint:#{char}:#{modifier}") }
end

describe Fingers::View do
  it "joins the selected halves of a split path without separator on enter" do
    state = Fingers::State.new
    view, hinter = build_view(SPLIT_PATH_INPUT, state)
    view.render

    view.process_input("toggle-multi-mode")
    select_hint(view, hint_for(hinter, "/Users/me/projects/tmux-fingers/src/fin"))
    select_hint(view, hint_for(hinter, "gers/commands/start.cr"))
    view.process_input("join-multi-mode")

    state.exiting.should be_true
    state.multi_mode.should be_false
    state.result.should eq("/Users/me/projects/tmux-fingers/src/fingers/commands/start.cr")
  end

  it "keeps the selection order when joining" do
    state = Fingers::State.new
    view, hinter = build_view(SPLIT_PATH_INPUT, state)
    view.render

    view.process_input("toggle-multi-mode")
    select_hint(view, hint_for(hinter, "gers/commands/start.cr"))
    select_hint(view, hint_for(hinter, "/Users/me/projects/tmux-fingers/src/fin"))
    view.process_input("join-multi-mode")

    state.result.should eq("gers/commands/start.cr/Users/me/projects/tmux-fingers/src/fin")
  end

  it "passes the modifier of the last selected hint to the action" do
    state = Fingers::State.new
    view, hinter = build_view(SPLIT_PATH_INPUT, state)
    view.render

    view.process_input("toggle-multi-mode")
    select_hint(view, hint_for(hinter, "/Users/me/projects/tmux-fingers/src/fin"))
    select_hint(view, hint_for(hinter, "gers/commands/start.cr"), "shift")
    view.process_input("join-multi-mode")

    state.modifier.should eq("shift")
  end

  it "still separates matches with spaces when leaving multi mode with the toggle key" do
    state = Fingers::State.new
    view, hinter = build_view(SPLIT_PATH_INPUT, state)
    view.render

    view.process_input("toggle-multi-mode")
    select_hint(view, hint_for(hinter, "/Users/me/projects/tmux-fingers/src/fin"))
    select_hint(view, hint_for(hinter, "gers/commands/start.cr"))
    view.process_input("toggle-multi-mode")

    state.exiting.should be_true
    state.result.should eq("/Users/me/projects/tmux-fingers/src/fin gers/commands/start.cr")
  end

  it "ignores enter outside multi mode" do
    state = Fingers::State.new
    view, _ = build_view(SPLIT_PATH_INPUT, state)
    view.render

    view.process_input("join-multi-mode")

    state.exiting.should be_false
    state.multi_mode.should be_false
    state.result.should eq("")
  end
end
