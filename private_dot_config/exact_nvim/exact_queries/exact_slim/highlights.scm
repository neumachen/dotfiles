;; Tag names
(tag
  name: (identifier) @tag)

;; Tag delimiters (classes/ids/etc.), adjust to real node names
(tag
  (tag_delimiter) @tag.delimiter)?

;; Attributes
(attribute
  name: (identifier) @attribute
  value: (string) @string)

;; Comments
(comment) @comment

;; Embedded Ruby (shape depends on grammar)
(ruby_block
  (ruby_code) @keyword.ruby)

;; Plain text
(text) @text
