# KDL document constructors (node/plain/leaf/flag) and serializer, used to author
# niri's config.kdl as plain data. Vendored verbatim from sodiboo/niri-flake's
# `kdl.nix` at rev 50e136c5452ae98638d066454391c7ba7e16410a
# (/nix/store/z83m5hxk5kn52054jnxgkbxy6l6vw2jk-source/kdl.nix) — why we vendor rather
# than depend: docs/design/niri-sourcing.md.
#
# Modified from the original: upstream's `types` block (the NixOS module-system types
# kdl-value/kdl-node/kdl-nodes/kdl-leaf/kdl-args/kdl-document, upstream :109-203 and
# :214-223) is omitted. It existed only to give niri-flake's `programs.niri.settings`
# its typed option surface, which this repo does not reproduce; `serialize` has no
# dependency on it. Everything retained below is byte-identical to upstream.
#
# MIT License
#
# Copyright (c) 2024 sodiboo
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
{ lib, ... }:
let
  fold-args =
    lib.foldl
      (
        self: arg:
        if lib.isAttrs arg then
          self // { properties = self.properties // arg; }
        else
          self // { arguments = self.arguments ++ [ arg ]; }
      )
      {
        arguments = [ ];
        properties = { };
      };
  node = name: args: children: {
    inherit name;
    inherit (fold-args (lib.toList args)) arguments properties;
    inherit children;
  };

  plain = name: node name [ ];
  leaf = name: args: node name args [ ];
  magic-leaf = node-name: {
    ${node-name} = [ ];
    __functor = self: arg: {
      inherit (self) __functor;
      ${node-name} = self.${node-name} ++ lib.toList arg;
    };
  };
  flag = name: node name [ ] [ ];

  serialize.string = lib.flip lib.pipe [
    (lib.escape [
      "\\"
      "\""
    ])
    # including newlines will cause the serialized output to contain additional indentation
    # so we escape them
    (lib.replaceStrings [ "\n" ] [ "\\n" ])
    (v: "\"${v}\"")
  ];
  serialize.path = serialize.string;
  serialize.int = toString;
  serialize.float = toString;
  serialize.bool = v: if v then "true" else "false";
  serialize.null = lib.const "null";

  serialize.value = v: serialize.${builtins.typeOf v} v;

  # this is not a complete list of valid identifiers
  # but it is good enough for niri
  # if this rejects a valid ident, literally nothing bad happens
  # essentially, this regex boils down to any sequence of letters, numbers or +/-
  # but not something that looks like a number (e.g. 0, -4, +12)
  bare-ident = "[A-Za-z][A-Za-z0-9+-]*|[+-]|[+-][A-Za-z+-][A-Za-z0-9+-]*";
  serialize.ident = v: if lib.strings.match bare-ident v != null then v else serialize.string v;

  serialize.prop =
    {
      name,
      value,
    }:
    "${serialize.ident name}=${serialize.value value}";

  single-indent = "    ";

  should-collapse =
    children:
    let
      length = lib.length children;
    in
    length == 0 || (length == 1 && should-collapse (lib.head children).children);

  serialize.node = serialize.node-with "";
  serialize.node-with =
    indent:
    {
      name,
      arguments,
      properties,
      children,
    }:
    indent
    + lib.concatStringsSep " " (
      lib.flatten [
        (serialize.ident name)
        (map serialize.value arguments)
        (map serialize.prop (lib.attrsToList properties))
        (
          if lib.length children == 0 then
            [ ]
          else if should-collapse children then
            "{ ${serialize.nodes children}; }"
          else
            "{\n${serialize.nodes-with (indent + single-indent) children}\n${indent}}"
        )
      ]
    );

  serialize.nodes = serialize.nodes-with "";
  serialize.nodes-with =
    indent:
    lib.flip lib.pipe [
      (map (serialize.node-with indent))
      (lib.concatStringsSep "\n")
    ];
in
{
  inherit
    node
    plain
    leaf
    magic-leaf
    flag
    serialize
    ;
}
