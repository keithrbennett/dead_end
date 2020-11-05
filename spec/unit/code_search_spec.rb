require_relative "../spec_helper.rb"

module SyntaxErrorSearch
  RSpec.describe CodeSearch do

    class FormatBlocks
      def initialize(block_array)
        @blocks = block_array
        @lines = @blocks.map(&:lines).flatten
        @digit_count = @lines.last.line_number.to_s.length
      end

      def to_s
        @lines.map do |line|
          number = line.line_number.to_s.rjust(@digit_count)
          "#{number} #{line}"
        end.join
      end
    end


    it "def with missing end" do
      search = CodeSearch.new(<<~EOM)
        class OH
          def hello
          def hai
          end
        end
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM.indent(2))
        def hello
        def hai
        end
      EOM
    end

    # For code that's not perfectly formatted, we ideally want to do our best
    # These examples represent the results that exist today, but I would like to improve upon them
    describe "needs improvement" do
      describe "missing describe/do line" do
        it "Format Code blocks real world example" do
          search = CodeSearch.new(<<~EOM)
            require 'rails_helper'

            RSpec.describe AclassNameHere, type: :worker do
              describe "thing" do
                context "when" do
                  let(:thing) { stuff }
                  let(:another_thing) { moarstuff }
                  subject { foo.new.perform(foo.id, true) }

                  it "stuff" do
                    subject

                    expect(foo.foo.foo).to eq(true)
                  end
                end
              end

                context "stuff" do
                  let(:thing) { create(:foo, foo: stuff) }
                  let(:another_thing) { create(:stuff) }

                  subject { described_class.new.perform(foo.id, false) }

                  it "more stuff" do
                    subject

                    expect(foo.foo.foo).to eq(false)
                  end
                end
              end
            end
          EOM
          search.call

          out = FormatBlocks.new(search.invalid_blocks).to_s
          expect(out).to eq(<<~EOM)
             4   describe "thing" do
            16   end
            30   end
          EOM
        end
      end

      describe "mis-matched-indentation" do
        it "stacked ends " do
          search = CodeSearch.new(<<~EOM)
            Foo.call
              def foo
                puts "lol"
                puts "lol"
            end
            end
          EOM
          search.call

          # Does not include the line with the error Foo.call
          expect(search.invalid_blocks.join).to eq(<<~EOM)
              def foo
            end
            end
          EOM
        end

        it "extra space before end" do
          search = CodeSearch.new(<<~EOM)
            Foo.call
              def foo
                puts "lol"
                puts "lol"
               end
            end
          EOM
          search.call

          # Does not include the line with the error Foo.call
          expect(search.invalid_blocks.join).to eq(<<~EOM.indent(3))
            end
          EOM
        end

        it "missing space before end" do
          search = CodeSearch.new(<<~EOM)
            Foo.call
              def foo
                puts "lol"
                puts "lol"
             end
            end
          EOM
          search.call

          # Does not include the line with the error Foo.call
          expect(search.invalid_blocks.join).to eq(<<~EOM)
            end
          EOM
        end
      end
    end

    it "returns syntax error in outer block without inner block" do
      search = CodeSearch.new(<<~EOM)
        Foo.call
          def foo
            puts "lol"
            puts "lol"
          end
        end
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM)
        Foo.call
        end
      EOM
    end

    it "doesn't just return an empty `end`" do
      search = CodeSearch.new(<<~EOM)
        Foo.call

        end
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM)
        Foo.call
        end
      EOM
    end

    it "finds multiple syntax errors" do
      search = CodeSearch.new(<<~EOM)
        describe "hi" do
          Foo.call
          end
        end

        it "blerg" do
          Bar.call
          end
        end
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM.indent(2))
        Foo.call
        end
        Bar.call
        end
      EOM
    end

    it "finds a typo def" do
      search = CodeSearch.new(<<~EOM)
        defzfoo
          puts "lol"
        end
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM)
        defzfoo
        end
      EOM
    end

    it "finds a mis-matched def" do
      search = CodeSearch.new(<<~EOM)
        def foo
          def blerg
        end
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM.indent(2))
        def blerg
      EOM
    end

    it "finds a naked end" do
      search = CodeSearch.new(<<~EOM)
        def foo
          end
        end
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM.indent(2))
        end
      EOM
    end

    it "returns when no invalid blocks are found" do
      search = CodeSearch.new(<<~EOM)
        def foo
          puts 'lol'
        end
      EOM
      search.call

      expect(search.invalid_blocks).to eq([])
    end
  end
end
