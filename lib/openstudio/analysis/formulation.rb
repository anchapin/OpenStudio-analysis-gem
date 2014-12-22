# OpenStudio formulation class handles the generation of the OpenStudio Analysis format.
module OpenStudio
  module Analysis

    SeedModel = Struct.new(:path)
    WeatherFile = Struct.new(:path)

    class Formulation

      attr_reader :seed_model
      attr_reader :weather_file
      attr_accessor :display_name
      attr_accessor :workflow
      attr_accessor :algorithm

      attr_reader :analysis_type


      # Create an instance of the OpenStudio::Analysis::Formulation
      #
      # @param display_name [String] Display name of the project.
      # @return [Object] An OpenStudio::Analysis::Formulation object
      def initialize(display_name)
        @display_name = display_name
        @analysis_type = nil
        @outputs = []

        # Initialize child objects (expect workflow)
        @weather_file = WeatherFile.new
        @seed_model = SeedModel.new
        @algorithm = OpenStudio::Analysis::AlgorithmAttributes.new
      end

      # Initialize or return the current workflow object
      #
      # @return [Object] An OpenStudio::Analysis::Workflow object
      def workflow
        @workflow ||= OpenStudio::Analysis::Workflow.new
      end

      # Define the type of analysis that this is going to be running
      #
      # @param name [String] Name of the algorithm/analysis. (e.g. rgenoud, lhs, single_run)
      def analysis_type=(name)
        @analysis_type = name
      end

      # Path to the seed model
      #
      # @param path [String] Path to the seed model. This should be relative.
      def seed_model(path)
        @seed_model = SeedModel.new(path: path)
      end

      # Path to the weather file (or folder). If it is a folder, then the measures will look for the weather file
      # by name in that folder.
      #
      # @param path [String] Path to the weather file or folder.
      def weather_file(path)
        @weather_file = WeatherFile.new(path: path)
      end

      # Add an output of interest to the problem formulation
      #
      # @param output_hash [Hash] Hash of the output variable in the legacy format
      # @option output_hash [String] :display_name Name to display
      # @option output_hash [String] :display_name_short A shorter display name
      # @option output_hash [String] :metadata_id Link to DEnCity ID in which this output corresponds
      # @option output_hash [String] :name Unique machine name of the variable. Typically this is measure.attribute
      # @option output_hash [String] :export Export the variable to CSV and dataframes from OpenStudio-server
      # @option output_hash [String] :visualize Visualize the variable in the plots on OpenStudio-server
      # @option output_hash [String] :units Units of the variable as a string
      # @option output_hash [String] :variable_type Data type of the variable
      # @option output_hash [Boolean] :objective_function Whether or not this output is an objective function. Default: false
      # @option output_hash [Integer] :objective_function_index Index of the objective function. Default: nil
      # @option output_hash [Float] :objective_function_target Target for the objective function to reach (if defined). Default: nil
      # @option output_hash [Float] :scaling_factor How to scale the objective function(s). Default: nil
      # @option output_hash [Integer] :objective_function_group If grouping objective functions, then group ID. Default: nil
      def add_output(output_hash)
        output_hash = {
            units: '',
            objective_function: false,
            objective_function_index: nil,
            objective_function_target: nil,
            objective_function_group: nil,
            scaling_factor: nil
        }.merge(output_hash)

        @outputs << output_hash
      end

      # return a hash.
      #
      # @param version [Integer] Version of the format to return
      # @return [Hash]
      def to_hash(version = 1)
        #fail 'Must define an analysis type' unless @analysis_type
        if version == 1
          h = {
              analysis: {
                  display_name: @display_name,
                  name: @display_name.snake_case,
                  output_variables: @outputs,
                  problem: {
                      analysis_type: @analysis_type,
                      algorithm: algorithm.to_hash(version),
                      workflow: workflow.to_hash(version)
                  },
                  seed: @seed_model[:path],
                  weather_file: @weather_file[:path],
                  file_format_version: version
              }
          }

          # This is a hack right now, but after the initial hash is created go back and add in the objective functions
          # to the the algorithm as defined in the output_variables list
          ofs = @outputs.map { |i| i[:name] if i[:objective_function] }.compact
          if h[:analysis][:problem][:algorithm]
            h[:analysis][:problem][:algorithm][:objective_functions] = ofs
          end

          h
        else
          fail "Version #{version} not defined for #{self.class} and #{__method__}"
        end
      end

      # return a hash of the data point with the static variables set
      #
      # @param version [Integer] Version of the format to return
      # @return [Hash]
      def to_static_data_point_hash(version = 1)
        if version == 1
          static_hash = {}
          # TODO: this method should be on the workflow step and bubbled up to this interface
          @workflow.items.map do |item|
            item.variables.map { |v| static_hash[v[:uuid]] = v[:static_value] }
          end

          h = {
              data_point: {
                  set_variable_values: static_hash,
                  status: 'na',
                  uuid: SecureRandom.uuid
              }
          }
          h
        end
      end

      # save the file to JSON. Will overwrite the file if it already exists
      #
      # @param version [Integer] Version of the format to return
      # @return [Boolean]
      def save(filename, version = 1)
        File.open(filename, 'w') { |f| f << JSON.pretty_generate(self.to_hash(version)) }

        true
      end

      # save the data point JSON with the variables set to the static values. Will overwrite the file if it already exists
      #
      # @param version [Integer] Version of the format to return
      # @return [Boolean]
      def save_static_data_point(filename, version = 1)
        File.open(filename, 'w') { |f| f << JSON.pretty_generate(self.to_static_data_point_hash(version)) }

        true
      end

    end
  end
end