# frozen_string_literal: true

require 'd-parse'

module Clarke
  module Grammar
    extend DParse::DSL

    # Whitespace

    WHITESPACE_CHAR =
      alt(
        char(' '),
        char("\t"),
        char("\n"),
        char("\r"),
      )

    SPACE_OR_TAB =
      alt(
        char(' '),
        char("\t"),
      )

    WHITESPACE0 =
      repeat(WHITESPACE_CHAR)

    WHITESPACE1 =
      seq(WHITESPACE_CHAR, WHITESPACE0)

    LINE_BREAK =
      seq(
        repeat(SPACE_OR_TAB),
        char("\n"),
        WHITESPACE0,
      )

    # Basic components

    DIGIT = char_in('0'..'9')
    LETTER = char_in('a'..'z')
    UNDERSCORE = char('_')

    # Primitives

    NUMBER =
      repeat1(DIGIT)
      .capture
      .map do |data, success, old_pos|
        context = Clarke::AST::Context.new(input: success.input, from: old_pos, to: success.pos)
        Clarke::AST::IntegerLiteral.new(data.to_i, context)
      end

    TRUE =
      string('true').map do |_data, success, old_pos|
        context = Clarke::AST::Context.new(input: success.input, from: old_pos, to: success.pos)
        Clarke::AST::TrueLiteral.new(context)
      end

    FALSE =
      string('false').map do |_data, success, old_pos|
        context = Clarke::AST::Context.new(input: success.input, from: old_pos, to: success.pos)
        Clarke::AST::FalseLiteral.new(context)
      end

    STRING =
      seq(
        char('"').ignore,
        repeat(
          alt(
            string('\"').capture.map { |_| '"' },
            char_not('"').capture,
          ),
        ),
        char('"').ignore,
      ).compact.first.map do |data, success, old_pos|
        context = Clarke::AST::Context.new(input: success.input, from: old_pos, to: success.pos)
        Clarke::AST::StringLiteral.new(data.join(''), context)
      end

    # … Other …

    RESERVED_WORD =
      describe(
        alt(
          string('else'),
          string('false'),
          string('fun'),
          string('if'),
          string('in'),
          string('let'),
          string('true'),
        ),
        'reserved keyword',
      )

    IDENTIFIER =
      except(
        describe(
          seq(
            alt(
              LETTER,
              UNDERSCORE,
            ),
            repeat(
              alt(
                LETTER,
                UNDERSCORE,
                NUMBER,
              ),
            ),
          ).capture,
          'identifier',
        ),
        RESERVED_WORD,
      )

    VARIABLE_NAME = IDENTIFIER

    VARIABLE_REF =
      VARIABLE_NAME.map do |data, success, old_pos|
        context = Clarke::AST::Context.new(input: success.input, from: old_pos, to: success.pos)
        Clarke::AST::Var.new(data, context)
      end

    ARGLIST =
      seq(
        char('(').ignore,
        opt(
          intersperse(
            seq(
              WHITESPACE0.ignore,
              lazy { EXPRESSION },
              WHITESPACE0.ignore,
            ).compact.first,
            char(',').ignore,
          ).select_even,
        ).map { |d| d || [] },
        char(')').ignore,
      ).compact.first

    FUNCTION_CALL_BASE =
      alt(
        VARIABLE_REF,
        lazy { PARENTHESISED_EXPRESSION },
      )

    FUNCTION_CALL =
      seq(
        FUNCTION_CALL_BASE,
        repeat1(ARGLIST),
      ).compact.map do |data, success, old_pos|
        context = Clarke::AST::Context.new(input: success.input, from: old_pos, to: success.pos)
        data[1].reduce(data[0]) do |memo, arglist|
          Clarke::AST::FunctionCall.new(memo, arglist, context)
        end
      end

    SCOPE =
      seq(
        char('{').ignore,
        WHITESPACE0.ignore,
        intersperse(lazy { EXPRESSION }, WHITESPACE1).select_even,
        WHITESPACE0.ignore,
        char('}').ignore,
      ).compact.first.map do |data, success, old_pos|
        context = Clarke::AST::Context.new(input: success.input, from: old_pos, to: success.pos)
        Clarke::AST::Scope.new(data, context)
      end

    ASSIGNMENT =
      seq(
        string('let').ignore,
        WHITESPACE1.ignore,
        VARIABLE_NAME,
        WHITESPACE0.ignore,
        char('=').ignore,
        WHITESPACE0.ignore,
        lazy { EXPRESSION },
        opt(
          seq(
            WHITESPACE1.ignore,
            string('in').ignore,
            WHITESPACE1.ignore,
            lazy { EXPRESSION },
          ).compact.first,
        ),
      ).compact.map do |data, success, old_pos|
        context = Clarke::AST::Context.new(input: success.input, from: old_pos, to: success.pos)
        if data[2]
          Clarke::AST::ScopedLet.new(data[0], data[1], data[2], context)
        else
          Clarke::AST::Assignment.new(data[0], data[1], context)
        end
      end

    IF =
      seq(
        string('if').ignore,
        WHITESPACE0.ignore,
        char('(').ignore,
        WHITESPACE0.ignore,
        lazy { EXPRESSION },
        WHITESPACE0.ignore,
        char(')').ignore,
        WHITESPACE0.ignore,
        SCOPE,
        WHITESPACE0.ignore,
        string('else').ignore,
        WHITESPACE0.ignore,
        SCOPE,
      ).compact.map do |data, success, old_pos|
        context = Clarke::AST::Context.new(input: success.input, from: old_pos, to: success.pos)
        Clarke::AST::If.new(data[0], data[1], data[2], context)
      end

    FUN_LAMBDA_DEF =
      seq(
        string('fun').ignore,
        WHITESPACE1.ignore,
        char('(').ignore,
        opt(
          intersperse(
            seq(
              WHITESPACE0.ignore,
              VARIABLE_NAME,
              WHITESPACE0.ignore,
            ).compact.first,
            char(',').ignore,
          ).select_even,
        ).map { |d| d || [] },
        char(')').ignore,
        WHITESPACE0.ignore,
        SCOPE,
      ).compact.map do |data, success, old_pos|
        context = Clarke::AST::Context.new(input: success.input, from: old_pos, to: success.pos)
        Clarke::AST::LambdaDef.new(data[0], data[1], context)
      end

    ARROW_LAMBDA_DEF =
      seq(
        char('(').ignore,
        opt(
          intersperse(
            seq(
              WHITESPACE0.ignore,
              VARIABLE_NAME,
              WHITESPACE0.ignore,
            ).compact.first,
            char(',').ignore,
          ).select_even,
        ).map { |d| d || [] },
        char(')').ignore,
        WHITESPACE0.ignore,
        string('=>').ignore,
        WHITESPACE0.ignore,
        lazy { EXPRESSION },
      ).compact.map do |data, success, old_pos|
        context = Clarke::AST::Context.new(input: success.input, from: old_pos, to: success.pos)
        Clarke::AST::LambdaDef.new(data[0], Clarke::AST::Scope.new([data[1]]), context)
      end

    LAMBDA_DEF =
      alt(
        FUN_LAMBDA_DEF,
        ARROW_LAMBDA_DEF,
      )

    OPERATOR =
      alt(
        char('^'),
        char('*'),
        char('/'),
        char('+'),
        char('-'),
        string('=='),
        string('>='),
        string('>'),
        string('<='),
        string('<'),
        string('&&'),
        string('||'),
      ).capture.map do |data, success, old_pos|
        context = Clarke::AST::Context.new(input: success.input, from: old_pos, to: success.pos)
        Clarke::AST::Op.new(data, context)
      end

    PARENTHESISED_EXPRESSION =
      seq(
        char('(').ignore,
        WHITESPACE0.ignore,
        lazy { EXPRESSION },
        WHITESPACE0.ignore,
        char(')').ignore,
      ).compact.first

    OPERAND =
      alt(
        TRUE,
        FALSE,
        STRING,
        FUNCTION_CALL,
        NUMBER,
        ASSIGNMENT,
        SCOPE,
        IF,
        LAMBDA_DEF,
        VARIABLE_REF,
        PARENTHESISED_EXPRESSION,
      )

    EXPRESSION =
      intersperse(
        OPERAND,
        seq(
          WHITESPACE0.ignore,
          OPERATOR,
          WHITESPACE0.ignore,
        ).compact.first,
      ).map do |data, success, old_pos|
        context = Clarke::AST::Context.new(input: success.input, from: old_pos, to: success.pos)
        Clarke::AST::OpSeq.new(data, context)
      end

    STATEMENTS =
      intersperse(
        EXPRESSION,
        LINE_BREAK,
      ).select_even

    PROGRAM = seq(WHITESPACE0.ignore, STATEMENTS, WHITESPACE0.ignore, eof.ignore).compact.first
  end
end
