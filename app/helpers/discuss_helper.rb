require 'cgi'

module DiscussHelper
  class DiscussMarkdownHTMLRender < Redcarpet::Render::HTML
    def block_code(code, language)
      code = CGI::escapeHTML code
      if APP_CONFIG.program_languages.keys.map(&:to_s).include? language
        "<pre class=\"prettyprint lang-#{language}\">\n#{code.gsub(/\t/, '    ')}</pre>"
      else
        "<pre>\n#{code.gsub(/\t/, '    ')}</pre>"
      end
    end

    def preprocess(text)
      text = text.gsub(/\r\n/, "\n").gsub(/\r/, "\n")
      flag = false
      res = ''
      text.each_line do |line|
        if flag
          flag = false if line =~ /\A\s{0,3}~~~\Z/
        else
          flag = true if line =~ /\A\s{0,3}~~~\s*\w*\s*\Z/
        end
        if flag
          res += line
        else
          if !line.empty? && line[0] == '=' && res.last == "\n"
            res.chop!
            res += line
          else
            res += line.gsub(/^\s*#/, "\\#").gsub(/^\s*-/, "\\-").gsub(/^\s*>/, "\\>")
          end
        end
      end
      res
    end
  end

  def new_markdown
    Redcarpet::Markdown.new(
        DiscussMarkdownHTMLRender.new(escape_html: true, no_styles: true, safe_links_only: true),
        no_intra_emphasis: true,
        fenced_code_blocks: true,
        autolink: true,
        lax_spacing: true
    )
  end

  def list_cache_name(user, problem)
    if user
      res = user.role
    else
      res = 'guest'
    end
    res = res + ":#{problem.id}" if problem
    res
  end

  def show_cache_name(user)
    if user
      user.role == 'admin' ? 'admin' : 'normal'
    else
      'guest'
    end
  end
end
