# frozen_string_literal: true

module Clarke
  module Interpreter
    module Runtime
      class Function < Dry::Struct
        attribute :parameters, Dry::Types::Any
        attribute :body, Dry::Types::Any
        attribute :env, Dry::Types::Any

        def describe
          'function'
        end

        def self.describe
          'function'
        end

        def clarke_to_string
          '<function>'
        end

        def bind(instance)
          new_env = env.push
          new_env['this'] = instance
          Function.new(
            parameters: parameters,
            body:       body,
            env:        new_env,
          )
        end

        def call(arguments, evaluator)
          case body
          when Clarke::AST::Block
            new_env =
              env.merge(Hash[parameters.zip(arguments)])
            evaluator.visit_block(body, new_env)
          when Proc
            body.call(evaluator, env, *arguments)
          end
        end
      end

      class Null < Dry::Struct
        include Singleton

        def describe
          'null'
        end

        def clarke_to_string
          'null'
        end

        def inspect
          '<Null>'
        end
      end

      class Class < Dry::Struct
        attribute :name, Dry::Types::Any
        attribute :functions, Dry::Types::Any

        def describe
          'class'
        end

        def self.describe
          'class'
        end

        def clarke_to_string
          '<Class>'
        end
      end

      # TODO: remove props?
      class Instance < Dry::Struct
        attribute :props, Dry::Types::Any
        attribute :klass, Dry::Types::Any

        def describe
          'instance'
        end

        def self.describe
          'instance'
        end

        def clarke_to_string
          '<Instance>'
        end
      end

      class String < Dry::Struct
        attribute :value, Dry::Types::Any

        def describe
          'string'
        end

        def self.describe
          'string'
        end

        def clarke_to_string
          value
        end
      end

      class Integer < Dry::Struct
        attribute :value, Dry::Types::Any

        def describe
          'integer'
        end

        def self.describe
          'integer'
        end

        def clarke_to_string
          value.to_s
        end

        def add(other)
          self.class.new(value: value + other.value)
        end

        def subtract(other)
          self.class.new(value: value - other.value)
        end

        def multiply(other)
          self.class.new(value: value * other.value)
        end

        def divide(other)
          self.class.new(value: value / other.value)
        end

        def exponentiate(other)
          self.class.new(value: value**other.value)
        end

        def eq(other)
          Boolean.new(value: value == other.value)
        end

        def gt(other)
          Boolean.new(value: value > other.value)
        end

        def lt(other)
          Boolean.new(value: value < other.value)
        end

        def gte(other)
          Boolean.new(value: value >= other.value)
        end

        def lte(other)
          Boolean.new(value: value <= other.value)
        end
      end

      class Boolean < Dry::Struct
        attribute :value, Dry::Types::Any

        def describe
          'boolean'
        end

        def self.describe
          'boolean'
        end

        def clarke_to_string
          value ? 'true' : 'false'
        end

        def eq(other)
          value == other.value ? True : False
        end

        def and(other)
          value && other.value ? True : False
        end

        def or(other)
          value || other.value ? True : False
        end
      end

      True = Boolean.new(value: true)
      False = Boolean.new(value: false)
    end
  end
end