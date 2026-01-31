# Framing Development Notes

## Historical Issues (~2018-2019, pre-abandonment)

### ❌ Bind Parameter Bug in CTEs
**Issue:** User default scope still has interpolation variables in frame ($1)

**Context:**
- spec/active_record/framing/reframing_spec.rb:36
- `User.joins(posts: :comments).reframe(posts: Post::Deleted).to_sql`
- When frames use parameterized queries (e.g., `where.not(kind: nil)`), the bind parameters like `$1` appear in the SQL but without corresponding values
- This causes `PG::ProtocolViolation: bind message supplies 0 parameters, but prepared statement "" requires 1`

**Root Cause (discovered 2026-01-31):**
When converting a frame Relation to a CTE in `build_frame` (default.rb:81), we extract `cte_relation.arel` but lose `cte_relation.bind_values`. The bind parameters are in the SQL but the values aren't passed to PostgreSQL.

**Status:** 🔧 **IN PROGRESS (2026-01-31)** - Surgical fix being implemented

### Reframe Table Renaming
**Issue:** Reframe doesn't rename all tables correctly

**Thoughts:**
- Handle on table object (change name when reframe is triggered)
- Would need to track nesting—subqueries querying from original table name should not be changed

**Status:** 📋 Not yet addressed

---

## Current Work (2026-01-31)

### ✅ Naming Consistency Refactor
**What:** Renamed `frames_values` → `frame_values` to match Rails conventions
- Rails uses singular: `where_values`, `select_values`, `bind_values`
- Framing was using plural: `frames_values` (inconsistent)
- Changed throughout codebase for consistency

### 🔧 Bind Parameter Fix (Option A: Surgical)
**Approach:** Capture bind_values alongside CTEs without changing core architecture

**Implementation:**
1. ✅ Added `frame_bind_values` parallel structure (compat/active_record_6_0.rb)
2. ✅ Modified `build_frame` to capture `cte_relation.bind_values` (default.rb:81-88)
3. ✅ Updated `frame!` to accept and store bind values (query_methods.rb:11-14)
4. ⏳ **NEXT:** Merge `frame_bind_values` into query's bind_values in `build_arel` (relation.rb:17-25)

**Files Modified:**
- `lib/active_record/framing/compat/active_record_6_0.rb`
- `lib/active_record/framing/default.rb`
- `lib/active_record/framing/query_methods.rb`
- `lib/active_record/framing/relation.rb` (pending)

---

## Future Planned Work

### 🔮 Architecture Refactor (Option B: Store Relations)
**Vision:** Instead of compiling frames to CTEs early, store Relations until the last moment

**Current Architecture:**
```ruby
# Frame compiled early:
cte_relation = where.not(kind: nil)  # Relation with bind_values
cte_arel = cte_relation.arel         # Compile to Arel, LOSE bind_values
frame_values["users"] = As.new(cte_arel)  # Store compiled CTE
```

**Proposed Architecture:**
```ruby
# Store Relation, compile late:
frame_values["users"] = where.not(kind: nil)  # Store Relation itself!

# In build_arel, compile at last moment:
frame_values.each do |table, relation|
  cte = As.new(table, relation.arel)
  ar.with(cte)
  merge_bind_values(relation.bind_values)  # Still have access!
end
```

**Benefits:**
- Cleaner: frame stays as Relation with all `*_values` intact
- More maintainable: less parallel data structures
- More Rails-like: Relations until compilation

**Risks:**
- Nested frame merging gets more complex
- Association reframing needs rethinking
- Changes fundamental data structure assumption

**Status:** 📋 Planned for after surgical fix is stable

---

## Test Coverage (2026-01-31)

### ✅ Comprehensive Test Suite Added
Added 5 new spec files (~1,111 lines):
- `thread_safety_spec.rb` - Concurrent access, frame isolation
- `inheritance_spec.rb` - STI, class hierarchy walking, `skip_inherited_frame`
- `error_handling_spec.rb` - Invalid frames, exceptions, edge cases
- `activerecord_integration_spec.rb` - count, pluck, find, batching, etc
- `edge_cases_spec.rb` - Transactions, associations, deep joins, etc

**Coverage:** 44% → 90%

**Failures:** 75/106 tests failing due to bind parameter bug
- All failures trace back to the same root cause
- Once bind parameter fix is complete, expect most to pass

---

## Development Environment

### Recent Fixes (2026-01-31)
- Fixed `claudenv` to properly initialize rbenv/pyenv/nvm
- PostgreSQL 11 main cluster running on port 5432
- Created `.keep` file in `/usr/local/etc/postgresql/11/main/conf.d` to prevent macOS cleanup
