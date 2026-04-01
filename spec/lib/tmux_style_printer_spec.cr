require "spec"
require "../../src/tmux_style_printer"

describe TmuxStylePrinter do
  it "transforms tmux status line format into escape sequences" do
    printer = TmuxStylePrinter.new
    result = printer.print("bg=red,fg=yellow,bold", reset_styles_after: true)
    expected = "\033[41m\033[33m\033[1m\033[0m"

    result.should eq expected
  end

  it "handles 256-color codes" do
    printer = TmuxStylePrinter.new
    result = printer.print("fg=colour123")
    expected = "\033[38;5;123m"

    result.should eq expected
  end

  it "handles bg 256-color codes" do
    printer = TmuxStylePrinter.new
    result = printer.print("bg=color200")
    expected = "\033[48;5;200m"

    result.should eq expected
  end

  it "handles dim style" do
    printer = TmuxStylePrinter.new
    result = printer.print("dim")
    expected = "\033[2m"

    result.should eq expected
  end

  it "handles reverse style" do
    printer = TmuxStylePrinter.new
    result = printer.print("reverse")
    expected = "\033[7m"

    result.should eq expected
  end

  it "handles italics style" do
    printer = TmuxStylePrinter.new
    result = printer.print("italics")
    expected = "\033[3m"

    result.should eq expected
  end

  it "handles underscore style" do
    printer = TmuxStylePrinter.new
    result = printer.print("underscore")
    expected = "\033[4m"

    result.should eq expected
  end
end
