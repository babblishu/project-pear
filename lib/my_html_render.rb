class MyHTMLRender < Redcarpet::Render::HTML
  def block_code(code, language)
    "<pre class=\"prettyprint lang-#{language}\">\n#{code.gsub(/\t/, '    ')}</pre>"
  end
end
