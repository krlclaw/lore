module ApplicationHelper
  def highlight_terms(text, words)
    return h(text) if words.blank?
    escaped = h(text)
    words.each do |word|
      pattern = Regexp.new("(#{Regexp.escape(word)})", Regexp::IGNORECASE)
      escaped = escaped.gsub(pattern, '<mark class="search-highlight">\1</mark>')
    end
    escaped.html_safe
  end
end
