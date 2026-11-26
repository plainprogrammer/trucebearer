module JoinCodeHelper
  # Six characters in two groups of three, in mono type. The element holds the text, so it can be selected and read aloud.
  def join_code_text(code)
    first, second = JoinCode.groups(code)
    tag.p(safe_join([ tag.span(first, class: "join-code__group"), " ", tag.span(second, class: "join-code__group") ]),
          class: "join-code mono")
  end
end
