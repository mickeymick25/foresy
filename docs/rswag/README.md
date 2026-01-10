# RSwag Documentation & Standards

This folder contains the complete RSwag documentation, standards, and architectural decisions for the Foresy API project.

## 📁 Organization

```
rswag/
├── guide.md           # Complete RSwag methodology and examples
├── adr/              # Architecture Decision Records (ADRs)
│   └── ADR-001-rswag-authentication-strategy.md
└── README.md         # This file
```

## 📖 Documentation

### guide.md
**Complete RSwag Methodology & Examples**

- Canonical patterns for RSwag specifications
- Authentication strategies (JWT via real login)
- Template examples for CRUD operations
- Common pitfalls and best practices
- Step-by-step implementation guide

**👉 Start here for learning and implementation**

### adr/ADR-001-rswag-authentication-strategy.md
**Architecture Decision: JWT Authentication**

- Fixed architectural decisions (cannot be changed)
- Authentication rules and forbidden patterns
- Implementation constraints and requirements
- Technical rationale and trade-offs

**👉 Reference for architectural decisions**

## 🚀 Quick Start

### For New Endpoints
1. Read `guide.md` for methodology
2. Copy existing templates from the spec directory
3. Follow the canonical patterns
4. Ensure ADR-001 compliance

### For Reviews
1. Check guide.md for standards
2. Verify ADR-001 compliance
3. Ensure consistent with existing patterns

### For Architecture Changes
1. Review existing ADRs
2. Create new ADR if needed
3. Update guide.md with new examples

## 🔧 Standards Overview

### ✅ Canonical Authentication
```ruby
# CORRECT - Real API authentication
let(:Authorization) { "Bearer #{authenticate(user)}" }

# INCORRECT - Manual JWT generation (FORBIDDEN)
let(:token) { JWT.encode(user_id, secret, algorithm) }
```

### ✅ RSwag DSL
```ruby
# CORRECT - Parameter declaration
parameter name: :Authorization, in: :header, type: :string

# INCORRECT - Header manipulation in before block
before { header 'Authorization', "Bearer #{token}" }
```

### ✅ Test Structure
```ruby
# CORRECT - Minimal setup, explicit data
let(:user) { create(:user, email: "test_#{SecureRandom.hex(4)}@example.com") }

# INCORRECT - Over-architected setup
let(:user) { create(:user, :with_independent_company, :with_missions) }
```

## 🏗️ Templates Available

Located in `spec/requests/api/v1/cras/swagger/`:

- `swagger_index_spec.rb` - GET /cras (list)
- `swagger_show_spec.rb` - GET /cras/:id (show)
- `swagger_create_spec.rb` - POST /cras (create)
- `swagger_update_spec.rb` - PATCH /cras/:id (update)
- `swagger_submit_spec.rb` - POST /cras/:id/submit (lifecycle)

## 🔒 Compliance

All RSwag specifications **MUST** comply with:

1. **ADR-001**: Authentication strategy rules
2. **guide.md**: Canonical patterns and examples
3. **Existing templates**: Consistent structure and style

## 📚 References

- **Complete Methodology**: `guide.md`
- **Authentication Rules**: `adr/ADR-001-rswag-authentication-strategy.md`
- **Helper Module**: `spec/support/swagger_auth_helper.rb`
- **Template Examples**: `spec/requests/api/v1/cras/swagger/`

## ⚠️ Important Notes

- **JWT.encode is FORBIDDEN** in RSwag specs
- **Real authentication API** must be used
- **Templates should be copied**, not referenced
- **Tests must reflect actual backend behavior**
- **Documentation is the source of truth**

---

*For questions or contributions, refer to this documentation first.*