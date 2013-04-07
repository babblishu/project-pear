module FaqHelper
  class FaqMarkdownHTMLRender < Redcarpet::Render::HTML
    def block_code(code, language)
      code = CGI::escapeHTML code
      if APP_CONFIG.program_languages.keys.map(&:to_s).include? language
        "<pre class=\"prettyprint lang-#{language}\">\n#{code.gsub(/\t/, '    ')}</pre>"
      else
        "<pre>\n#{code.gsub(/\t/, '    ')}</pre>"
      end
    end
  end

  def new_markdown
    Redcarpet::Markdown.new(
        FaqMarkdownHTMLRender,
        no_intra_emphasis: true,
        fenced_code_blocks: true,
        autolink: true,
        lax_spacing: true
    )
  end

  def show_cache_name
    admin? ? 'admin' : 'normal'
  end
end
