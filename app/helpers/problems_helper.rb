require 'cgi'

module ProblemsHelper
  class ProblemMarkdownHTMLRender < Redcarpet::Render::HTML
    def initialize(options = {})
      unless options[:parse_formula].nil?
        @parse_formula = options[:parse_formula]
        options.delete :parse_formula
      end
      super(options)
    end

    def block_code(code, language)
      code = CGI::escapeHTML code
      if APP_CONFIG.program_languages.keys.map(&:to_s).include? language
        "<pre class=\"prettyprint lang-#{language}\">\n#{code.gsub(/\t/, '    ')}</pre>"
      else
        "<pre>\n#{code.gsub(/\t/, '    ')}</pre>"
      end
    end

    def preprocess(text)
      return text unless @parse_formula

      res = ''
      need_escape = false
      inside_formula = false
      outside_formula = false
      formula = ''
      last_char = ''
      need_left_margin = false

      text.each_char do |ch|
        if inside_formula
          if ch == '$'
            outside_formula = true
            inside_formula = false
          else
            formula << ch
          end
        else
          if outside_formula
            outside_formula = false
            res << render_formula_span(formula, need_left_margin, ch != ' ')
            need_left_margin = false
            formula = ''
          end
          if ch == "\\"
            need_escape = true
          else
            if ch == '$' && !need_escape
              inside_formula = true
              need_left_margin = last_char != ' '
            else
              if need_escape
                res << "\\"
                need_escape = false
              end
              last_char = ch
              res << ch
            end
          end
        end
      end

      if inside_formula
        res << '$' << formula
      end
      if outside_formula
        res << render_formula_span(formula, need_left_margin, false)
      end

      res
    end

    private
    def render_formula_span(formula, need_left_margin, need_right_margin)
      formula.each_char do |ch|
        unless valid_formula_character(ch)
          return '<span class="formula error">[invalid character ' + ch + ']</span>'
        end
      end
      span_class = ['formula']
      span_class << 'with-left-margin' if need_left_margin
      span_class << 'with-right-margin' if need_right_margin
      '<span class="' + span_class.join(' ') + '">' + render_formula(formula) + '</span>'
    end

    def render_formula(formula)
      tmp = []
      formula.each_char { |ch| tmp << ch }

      len = tmp.size
      cur = 0
      res = ''
      while cur < len
        ch = tmp[cur]

        if is_letter(ch)
          res << '<i>' + ch + '</i>'
        end

        if is_operator(ch)
          pre = cur == 0 ? '' : tmp[cur - 1]
          ch = "\u{2212}" if ch == '-'
          ch = "\u{00D7}" if ch == '*'
          if ch == '<' && cur + 1 < len && tmp[cur + 1] == '='
            ch = "\u{2264}"
            cur += 1
          end
          if ch == '>' && cur + 1 < len && tmp[cur + 1] == '='
            ch = "\u{2265}"
            cur += 1
          end
          if ch == '<' && cur + 1 < len && tmp[cur + 1] == '>'
            ch = "\u{2260}"
            cur += 1
          end
          if pre == ''
            res << ch
          else
            res << '<span class="operator">' + ch + '</span>'
          end
        end

        if ch == '#'
          if cur + 1 < len && tmp[cur + 1] == '{'
            t = find_right_bracket tmp, cur + 1
            if t != -1
              (cur + 2).upto(t - 1) do |i|
                if tmp[i] == ' '
                  res << '&nbsp;'
                else
                  res << tmp[i]
                end
              end
              cur = t
            else
              res << ch
            end
          else
            res << ch
          end
        end

        if ch == '^' || ch == '_'
          tag = ch == '^' ? 'sup' : 'sub'
          if cur + 1 < len
            if tmp[cur + 1] == '{'
              t = find_right_bracket tmp, cur + 1
              if t != -1
                tmp_str = ''
                (cur + 2).upto(t - 1) { |i| tmp_str << tmp[i] }
                res << "<#{tag}>" << render_formula(tmp_str) << "</#{tag}>"
                cur = t
              else
                res << ch
              end
            else
              res << "<#{tag}>"
              if is_letter(tmp[cur + 1])
                res << '<i>' + tmp[cur + 1] + '</i>'
              else
                res << tmp[cur + 1]
              end
              res << "</#{tag}>"
              cur += 1
            end
          else
            res << '^'
          end
        end

        if ch == ','
          res << '<span class="comma">,</span>'
        end

        if ch == "\'"
          span_class = ['apostrophes']
          if cur > 0 && tmp[cur - 1] == ' '
            res << ' '
          else
            span_class << 'with-left-margin'
          end
          res << '<span class="' + span_class.join(' ') + '">' + ch + '</span>'
        end

        if is_bracket(ch) || ch == '|'
          span_class = ['bracket']
          span_class << 'with-left-margin' if cur > 0
          span_class << 'with-right-margin' if cur + 1 < len
          res << ' ' if ch == '(' && cur > 0 && tmp[cur - 1] == ' '
          res << '<span class="' + span_class.join(' ') + '">' + ch + '</span>'
        end

        if is_number(ch) || ch == '.' || ch == '!'
          res << ch
        end

        cur += 1
      end

      res
    end

    def valid_formula_character(ch)
      return true if is_letter(ch)
      return true if is_number(ch)
      return true if is_operator(ch)
      return true if is_bracket(ch)
      return true if ['#', '_', '^', ',', '.', '|', ' ', '!', "\'"].include? ch
      false
    end

    def is_number(ch)
      '0' <= ch && ch <= '9'
    end

    def is_letter(ch)
      'a' <= ch && ch <= 'z' || 'A' <= ch && ch <= 'Z' || "\u{0370}" <= ch && ch <= "\u{03FF}"
    end

    def is_operator(ch)
      return true if ['+', '-', '*', '/', '<', '>', '=', '~'].include? ch
      return true if ["\u{2212}", "\u{002D}"].include? ch
      return true if "\u{2200}" <= ch && ch <= "\u{22FF}"
      false
    end

    def is_bracket(ch)
      ['(', ')', '{', '}', '[', ']'].include? ch
    end

    def find_right_bracket(char_arr, start)
      cur = start
      cnt = 0
      while cur < char_arr.size
        cnt += 1 if char_arr[cur] == '{'
        cnt -= 1 if char_arr[cur] == '}'
        return cur if cnt == 0
        cur += 1
      end
      -1
    end
  end

  def new_markdown(enable_latex)
    Redcarpet::Markdown.new(
        ProblemMarkdownHTMLRender.new(parse_formula: !enable_latex),
        no_intra_emphasis: true,
        fenced_code_blocks: true,
        lax_spacing: true,
        autolink: true
    )
  end

  def list_cache_name(role, tag_ids)
    if tag_ids.empty?
      role
    else
      "#{role}:#{tag_ids.first}"
    end
  end
end
