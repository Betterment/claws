require "psych"
require "pry"

module Locatable
  attr_accessor :line
end

module Psych
  module Nodes
    class Node
      attr_accessor :line
    end
  end
end

module Psych
  module Visitors
    class ToRuby
      def accept(target)
        s = super(target)

        # types that we cannot monkey patch into holding line information
        if target.respond_to?(:line) and ![TrueClass, FalseClass, NilClass, Integer, Float].include? s.class
          s.instance_eval do
            extend(Locatable)
          end

          s.line = target.line
        end

        s
      end

      private

      def register_empty(object)
        list = register(object, [])
        object.children.each do |c|
          c.line = 0 if c.respond_to? :line and c.line.nil?
          c.line += 1 if c.respond_to? :line
          list.push accept c
        end
        list
      end

      def revive_hash(hash, o, _tagged: false) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Naming/MethodParameterName
        o.children.each_slice(2) do |k, v|
          key = accept(k)
          val = accept(v)

          key.line = 0 if key.respond_to? :line and key.line.nil?
          key.line += 1 if key.respond_to? :line
          key.freeze

          # types that we cannot monkey patch into holding line information
          if [TrueClass, FalseClass, NilClass, Integer, Float].include? key.class
            val.line = 0 if val.respond_to? :line and val.line.nil?
            val.line += 1 if val.respond_to? :line
          end

          hash[key] = val
        end

        hash
      end
    end
  end
end

class TreeBuilderWithLines < Psych::TreeBuilder
  attr_accessor :parser

  def scalar(value, anchor, tag, plain, quoted, style) # rubocop:disable Metrics/ParameterLists
    # github uses "on" in its schema for workflows, which
    # YAML 1.1 turns into a boolean. YAML 1.2 does not, but
    # Psych doesn't support that.
    # https://github.com/ruby/psych/blob/56d545e278/test/psych/test_boolean.rb#L9-L13
    quoted = true if value.downcase == "on"

    super(value, anchor, tag, plain, quoted, style).tap do |l|
      l.line = parser.mark.line
    end
  end

  def start_document(version, tag_directives, implicit)
    super(version, tag_directives, implicit).tap do |l|
      l.line = parser.mark.line
    end
  end

  def start_sequence(anchor, tag, implicit, style)
    super(anchor, tag, implicit, style).tap do |l|
      l.line = parser.mark.line
    end
  end

  def start_stream(encoding)
    super(encoding).tap do |l|
      l.line = parser.mark.line
    end
  end

  def start_mapping(anchor, tag, implicit, style)
    super(anchor, tag, implicit, style).tap do |l|
      l.line = parser.mark.line
    end
  end
end

class YAMLWithLines
  def self.load(blob)
    handler = TreeBuilderWithLines.new
    parser = Psych::Parser.new(handler)
    handler.parser = parser
    parser.parse(blob)
    parser.handler.root.to_ruby.first.tap do |c|
      c.instance_eval do
        @lines = blob.split("\n")

        def get_line(line:)
          raise "Line number must be positive and one-indexed" if line < 1

          @lines[line - 1]
        end
      end
    end
  end
end
