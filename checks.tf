# check blocks run after every plan and apply and emit a warning (without blocking) when an
# invariant is violated.

# A scope with no scoped services guards nothing, and a PrivateOnly scope with no scoped
# services blackholes whatever points at it: surface empty scopes.
check "scopes_have_scoped_services" {
  assert {
    condition = alltrue([
      for scope_name in keys(var.private_link_scopes) :
      anytrue([for s in values(var.scoped_services) : s.scope == scope_name])
    ])
    error_message = "A private link scope has no in-module scoped services; it guards nothing until workspaces, components, or collection endpoints are scoped into it (external scoped services by scope_name are invisible to this warning)."
  }
}
