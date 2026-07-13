# ANSI-16 name → slot projections — the fixed correspondences of the
# terminal colour bus (ADR-041). One home for translating a token role's
# `.ansi` name (lib/theme-tokens.nix) into a consumer's syntax: slot index
# (gh-dash YAML), classic SGR foreground code (the statusline colour
# bindings). Routing token-sourced values through here makes a role re-map
# propagate by eval — an off-table name is an eval error, not silent rot.
# Deliberately minimal: the 16 names and two projections, nothing else.
# Canonical colour literals in consumers stay direct (prompt.nix writes
# `blue` inline); only role-sourced values take this indirection.
# Plain attrset via `import` — the lib/ convention (see theme-tokens.nix).
let
  index = {
    black = 0;
    red = 1;
    green = 2;
    yellow = 3;
    blue = 4;
    magenta = 5;
    cyan = 6;
    white = 7;
    "bright-black" = 8;
    "bright-red" = 9;
    "bright-green" = 10;
    "bright-yellow" = 11;
    "bright-blue" = 12;
    "bright-magenta" = 13;
    "bright-cyan" = 14;
    "bright-white" = 15;
  };
in
{
  inherit index;

  # Classic SGR foreground code for a name: 30–37 for the normal slots,
  # 90–97 for the bright ones.
  fgCode =
    name:
    let
      i = index.${name};
    in
    if i < 8 then 30 + i else 90 + (i - 8);
}
