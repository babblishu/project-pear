require 'cgi'

class MyHTMLRender < Redcarpet::Render::HTML
  def block_code(code, language)
    code = CGI::escapeHTML code
    if language
      "<pre class=\"prettyprint lang-#{language}\">\n#{code.gsub(/\t/, '    ')}</pre>"
    else
      "<pre>\n#{code.gsub(/\t/, '    ')}</pre>"
    end
  end

  def preprocess(text)
    text.gsub(/^#/, '\\#').gsub(/^-/, '\\-').gsub(/\n=/, ' =').gsub(/^>/, '\\>')
  end
end
