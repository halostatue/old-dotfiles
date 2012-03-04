#!/usr/bin/env ruby

Pry.config.prompt = [
  proc { PROMPT.call(">>") },
  proc { PROMPT.call(" *") }
]
