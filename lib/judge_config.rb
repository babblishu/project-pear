require 'json'

module JudgeConfig
  class ConfigNotExist < StandardError; end
  class InvalidConfig < StandardError; end

  def parse_config(dir)
    raise ConfigNotExist unless dir.join('config.txt').file?
    tmp_config = {}
    begin
      File.open(dir.join('config.txt')) { |f| tmp_config = JSON.parse f.read, symbolize_names: true }
    rescue
      raise InvalidConfig
    end
    raise InvalidConfig unless tmp_config.is_a? Hash

    # default config
    tmp_config[:input_file_prefix] ||= ''
    tmp_config[:answer_file_prefix] ||= ''
    tmp_config[:input_file_extension] ||= 'in'
    tmp_config[:answer_file_extension] ||= 'out'
    tmp_config[:sample_input_prefix] ||= 'sample'
    tmp_config[:sample_output_prefix] ||= 'sample'
    tmp_config[:time_limit] ||= 1000
    tmp_config[:memory_limit] ||= 64

    config = {}
    detail_config = {}
    tmp_config.each do |key, value|
      case key
        when :input_file_prefix
          raise InvalidConfig unless value.is_a? String

        when :answer_file_prefix
          raise InvalidConfig unless value.is_a? String

        when :input_file_extension
          raise InvalidConfig unless value.is_a? String

        when :answer_file_extension
          raise InvalidConfig unless value.is_a? String

        when :sample_input_prefix
          raise InvalidConfig unless value.is_a? String

        when :sample_output_prefix
          raise InvalidConfig unless value.is_a? String

        when :contestant_input_file_name
          raise InvalidConfig unless value.is_a? String
          raise InvalidConfig if ['_in', '_out', '_err'].include? value
          config[:contestant_input_file_name] = value

        when :contestant_output_file_name
          raise InvalidConfig unless value.is_a? String
          raise InvalidConfig if ['_in', '_out', '_err'].include? value
          config[:contestant_output_file_name] = value

        when :time_limit
          raise InvalidConfig unless value.is_a? Fixnum
          raise InvalidConfig unless 0 <= value

        when :memory_limit
          raise InvalidConfig unless value.is_a? Fixnum
          raise InvalidConfig unless 0 <= value

        when :enable_O2_option
          raise InvalidConfig unless value.is_a?(TrueClass) || value.is_a?(FalseClass)
          config[:enable_O2_option] = value

        when :stack_size
          raise InvalidConfig unless value.is_a? Fixnum
          config[:stack_size] = value

        when :enable_special_judge
          raise InvalidConfig unless value.is_a?(TrueClass) || value.is_a?(FalseClass)
          config[:enable_special_judge] = value

        when :special_judge_language
          raise InvalidConfig unless value.is_a? String
          raise InvalidConfig unless ['c', 'cpp', 'pas'].include? value
          config[:special_judge_language] = value

        when :score
          raise InvalidConfig unless value.is_a? Array
          value.each do |x|
            raise InvalidConfig unless x.is_a? Fixnum
            raise InvalidConfig unless 0 < x && x <= 100
          end
          raise InvalidConfig unless value.reduce(:+) == 100

        when :detail_config
          raise InvalidConfig unless value.is_a? Hash
          detail_config = value
          value.each do |x, y|
            raise InvalidConfig unless x =~ /\A\d+[a-z]?\Z/
            raise InvalidConfig unless y.is_a? Hash
            y.each do |a, b|
              case a
                when :time_limit
                  raise InvalidConfig unless b.is_a? Fixnum
                  raise InvalidConfig unless 0 <= b
                when :memory_limit
                  raise InvalidConfig unless b.is_a? Fixnum
                  raise InvalidConfig unless 0 <= b
                else
                  raise InvalidConfig
              end
            end
          end

        else
          raise InvalidConfig
      end
    end

    if config[:enable_special_judge]
      raise InvalidConfig unless config[:special_judge_language]
      raise InvalidConfig unless dir.join("judge.#{config[:special_judge_language]}").file?
    end

    in_pre = tmp_config[:input_file_prefix]
    ans_pre = tmp_config[:answer_file_prefix]
    in_ext = tmp_config[:input_file_extension]
    ans_ext = tmp_config[:answer_file_extension]
    sample_in_pre = tmp_config[:sample_input_prefix]
    sample_out_pre = tmp_config[:sample_output_prefix]

    # sample test data
    if data_exist? dir, sample_in_pre, sample_out_pre, in_ext, ans_ext
      config[:sample_test_data] = [
          {
              input_file: "#{sample_in_pre}.#{in_ext}",
              output_file: "#{sample_out_pre}.#{ans_ext}",
              time_limit: tmp_config[:time_limit],
              memory_limit: tmp_config[:memory_limit]
          }
      ]
    else
      tmp_arr = []
      x = 1
      while data_exist? dir, "#{sample_in_pre}#{x}", "#{sample_out_pre}#{x}", in_ext, ans_ext
        tmp_arr << {
            input_file: "#{sample_in_pre}#{x}.#{in_ext}",
            output_file: "#{sample_out_pre}#{x}.#{ans_ext}",
            time_limit: tmp_config[:time_limit],
            memory_limit: tmp_config[:memory_limit]
        }
        x += 1
      end
      config[:sample_test_data] = tmp_arr
    end

    test_data = []
    x = 1
    loop do
      if data_exist? dir, "#{in_pre}#{x}", "#{ans_pre}#{x}", in_ext, ans_ext
        time_limit = tmp_config[:time_limit]
        memory_limit = tmp_config[:memory_limit]
        if detail_config[x.to_s.to_sym]
          time_limit = detail_config[x.to_s.to_sym][:time_limit] || time_limit
          memory_limit = detail_config[x.to_s.to_sym][:memory_limit] || memory_limit
        end
        test_data << [
            {
                input_file: "#{in_pre}#{x}.#{in_ext}",
                output_file: "#{ans_pre}#{x}.#{ans_ext}",
                time_limit: time_limit,
                memory_limit: memory_limit
            }
        ]
      else
        tmp_arr = []
        y = 'a'
        while data_exist? dir, "#{in_pre}#{x}#{y}", "#{ans_pre}#{x}#{y}", in_ext, ans_ext
          time_limit = tmp_config[:time_limit]
          memory_limit = tmp_config[:memory_limit]
          if detail_config["#{x}#{y}".to_sym]
            time_limit = detail_config["#{x}#{y}".to_sym][:time_limit] || time_limit
            memory_limit = detail_config["#{x}#{y}".to_sym][:memory_limit] || memory_limit
          end
          tmp_arr << {
              input_file: "#{in_pre}#{x}#{y}.#{in_ext}",
              output_file: "#{ans_pre}#{x}#{y}.#{ans_ext}",
              time_limit: time_limit,
              memory_limit: memory_limit
          }
          y = y.succ
        end
        break if tmp_arr.empty?
        test_data << tmp_arr
      end
      x = x.succ
    end
    raise InvalidConfig if test_data.empty?
    config[:test_data] = test_data

    if tmp_config[:score]
      raise InvalidConfig unless tmp_config[:score].size == test_data.size
      config[:score] = tmp_config[:score]
    else
      raise InvalidConfig if test_data.size > 100
      x = 100 / test_data.size
      y = 100 % test_data.size
      config[:score] = [x] * (test_data.size - y) + [x + 1] * y
    end

    config
  end

  def data_exist?(dir, in_name, ans_name, in_ext, ans_ext)
    dir.join("#{in_name}.#{in_ext}").file? && dir.join("#{ans_name}.#{ans_ext}").file?
  end
end
