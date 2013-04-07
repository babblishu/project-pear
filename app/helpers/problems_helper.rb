require 'cgi'

module ProblemsHelper
  class ProblemMarkdownHTMLRender < Redcarpet::Render::HTML
    def block_code(code, language)
      code = CGI::escapeHTML code
      if APP_CONFIG.program_languages.keys.map(&:to_s).include? language
        "<pre class=\"prettyprint lang-#{language}\">\n#{code.gsub(/\t/, '    ')}</pre>"
      else
        "<pre>\n#{code.gsub(/\t/, '    ')}</pre>"
      end
    end
  end

  def new_markdown(enable_latex)
    Redcarpet::Markdown.new(
        ProblemMarkdownHTMLRender,
        no_intra_emphasis: true,
        fenced_code_blocks: true,
        lax_spacing: true,
        autolink: true,
        superscript: !enable_latex
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
