;; Slim Treesitter highlight queries
;; Only use node types that actually belong to the Slim grammar.

;; Whole tag line (e.g. `.foo.bar` or `div.class`)
(tag) @tag

;; Tag names like `div`, `span`, etc.
(tag
  name: (tag_name) @tag.name)

;; Classes like `.foo`, `.bar`
(tag_class) @tag.attribute

;; Parameters: e.g. [foo="bar"]
(parameter_name) @attribute
(parameter_value
  (string_content) @string)

;; Comments (including those with ruby_interpolation inside)
(comment) @comment

;; Lines starting with `-` / `=` etc. (Slim directives)
(directive_sign) @operator
(directive_block) @tag
