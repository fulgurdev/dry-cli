# frozen_string_literal: true

require 'optparse'
require 'dry/cli/program_name'

module Dry
  class CLI
    # Parse command line arguments and options
    #
    # @since 0.1.0
    # @api private
    module Parser
      # @since 0.1.0
      # @api private
      #
      def self.call(command, arguments, prog_name, meta)
        original_arguments = arguments.dup

        command_options, command_arguments = preprocess_arguments(arguments)

        parsed_options = {}

        OptionParser.new do |opts|
          command.options.each do |option|
            opts.on(*option.parser_options) do |value|
              parsed_options[option.name.to_sym] = value
            end
          end

          opts.on_tail('-h', '--help') do
            return Result.help
          end
        end.parse!(command_options)

        parsed_options = command.default_params.merge(parsed_options)
        parse_required_params(command, command_arguments, prog_name, parsed_options, meta)
      rescue ::OptionParser::ParseError
        Result.failure("ERROR: \"#{prog_name}\" was called with arguments \"#{original_arguments.join(' ')}\"") # rubocop:disable Metrics/LineLength
      end

      # @since 0.1.0
      # @api private
      #
      # rubocop:disable Metrics/AbcSize
      def self.parse_required_params(command, arguments, prog_name, parsed_options, meta)
        parsed_params          = match_arguments(command.arguments, arguments)
        parsed_required_params = match_arguments(command.required_arguments, arguments)
        all_required_params_satisfied = command.required_arguments.all? { |param| !parsed_required_params[param.name].nil? } # rubocop:disable Metrics/LineLength

        unused_arguments = arguments.drop(command.required_arguments.length)

        unless all_required_params_satisfied
          parsed_required_params_values = parsed_required_params.values.compact

          usage = "\nUsage: \"#{prog_name} #{command.required_arguments.map(&:description_name).join(' ')}" # rubocop:disable Metrics/LineLength

          usage += " | #{prog_name} SUBCOMMAND" if command.subcommands.any?

          usage += '"'

          if parsed_required_params_values.empty?
            return Result.failure("ERROR: \"#{prog_name}\" was called with no arguments#{usage}") # rubocop:disable Metrics/LineLength
          else
            return Result.failure("ERROR: \"#{prog_name}\" was called with arguments #{parsed_required_params_values}#{usage}") # rubocop:disable Metrics/LineLength
          end
        end

        parsed_params.reject! { |_key, value| value.nil? }
        parsed_options = parsed_options.merge(parsed_params)
        parsed_options[:args] = {}
        parsed_options[:args][:unused] = unused_arguments
        parsed_options[:args][:meta] = meta
        Result.success(parsed_options)
      end
      # rubocop:enable Metrics/AbcSize

      def self.match_arguments(command_arguments, arguments)
        result = {}

        command_arguments.each_with_index do |cmd_arg, index|
          if cmd_arg.array?
            result[cmd_arg.name] = arguments[index..-1]
            break
          else
            result[cmd_arg.name] = arguments.at(index)
          end
        end

        result
      end

      def self.preprocess_arguments(arguments)
        option_name_regexp = /--?[a-zA-z]+=?/

        options_array = arguments.select.with_index do |argument, index|
          argument.match(option_name_regexp) || (index != 0 && arguments[index - 1].match(option_name_regexp))
        end

        arguments_array = arguments.select.with_index do |argument, index|
          !(argument.match(option_name_regexp) || (index != 0 && arguments[index - 1].match(option_name_regexp)))
        end


        [options_array, arguments_array]
      end

      # @since 0.1.0
      # @api private
      class Result
        # @since 0.1.0
        # @api private
        def self.help
          new(help: true)
        end

        # @since 0.1.0
        # @api private
        def self.success(arguments = {})
          new(arguments: arguments)
        end

        # @since 0.1.0
        # @api private
        def self.failure(error = 'Error: Invalid param provided')
          new(error: error)
        end

        # @since 0.1.0
        # @api private
        attr_reader :arguments

        # @since 0.1.0
        # @api private
        attr_reader :error

        # @since 0.1.0
        # @api private
        def initialize(arguments: {}, error: nil, help: false)
          @arguments = arguments
          @error     = error
          @help      = help
        end

        # @since 0.1.0
        # @api private
        def error?
          !error.nil?
        end

        # @since 0.1.0
        # @api private
        def help?
          @help
        end
      end
    end
  end
end
