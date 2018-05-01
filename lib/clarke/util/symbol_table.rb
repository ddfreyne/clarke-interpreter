# frozen_string_literal: true

module Clarke
  module Util
    class SymbolTable
      UNDEFINED = Object.new

      def initialize(contents: {}, parent: nil)
        @contents = contents
        @parent = parent
      end

      def define(sym)
        self.class.new(
          parent: @parent,
          contents: @contents.merge(sym.name.to_s => sym),
        )
      end

      def resolve(name, fallback = UNDEFINED)
        name = name.to_s

        if @contents.key?(name)
          @contents.fetch(name)
        elsif @parent
          @parent.resolve(name, fallback)
        elsif UNDEFINED.equal?(fallback)
          raise Clarke::Language::NameError.new(name)
        else
          fallback
        end
      end

      def inspect
        "<SymbolTable #{@contents.values.inspect}\n#{_indent(@parent.inspect)}>"
      end

      def push
        self.class.new(parent: self)
      end

      def _indent(lines)
        lines.each_line.map { |l| '  ' + l }.join('')
      end
    end
  end
end
